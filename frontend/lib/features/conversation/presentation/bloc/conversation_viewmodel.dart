import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:bloc/bloc.dart';

import 'package:frontend/core/audio_recorder/audio_recorder_service.dart';
import 'package:frontend/core/utils/audio_chunk_buffer.dart';
import 'package:frontend/core/utils/vad_util.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';
import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:frontend/features/conversation/domain/usecases/connect_conversation_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/end_session_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/send_audio_chunk_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/start_session_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/switch_speaker_usecase.dart';

part 'conversation_state.dart';

/// ViewModel (Cubit) managing the real-time conversation translation session.
///
/// Implements the MVVM pattern using Cubit as the ViewModel layer.
/// All business logic is delegated to dedicated UseCases:
///
/// | Action             | UseCase                    |
/// |--------------------|----------------------------|
/// | Connect WS         | [ConnectConversationUseCase]|
/// | Start session      | [StartSessionUseCase]       |
/// | Send audio chunk   | [SendAudioChunkUseCase]     |
/// | Switch speaker     | [SwitchSpeakerUseCase]      |
/// | End session        | [EndSessionUseCase]         |
///
/// Lifecycle:
///   connect → startSession → recording ⇄ processing → endSession → disconnect
///
/// Audio flow:
///   Microphone → [AudioRecorderService] → [AudioChunkBuffer] → [SendAudioChunkUseCase]
///
/// The ViewModel listens to the [ConversationEvent] stream from the
/// repository and emits appropriate [ConversationState] subclasses.
/// The UI rebuilds via [BlocBuilder] / [BlocConsumer].
class ConversationViewModel extends Cubit<ConversationState> {
  final ConnectConversationUseCase _connectUseCase;
  final StartSessionUseCase _startSessionUseCase;
  final SendAudioChunkUseCase _sendAudioChunkUseCase;
  final SwitchSpeakerUseCase _switchSpeakerUseCase;
  final EndSessionUseCase _endSessionUseCase;
  final ConversationRepository _repository;
  final AuthLocalDataSource _authLocalDataSource;
  final AudioRecorderService _audioRecorderService;

  StreamSubscription<ConversationEvent>? _eventSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;

  /// Audio chunk buffer — accumulates raw PCM and flushes 2-second chunks.
  final AudioChunkBuffer _audioBuffer = AudioChunkBuffer();

  /// Tracks when the current silence started for VAD.
  DateTime? _silenceStartTime;

  /// Threshold for automatic stop (1.5 seconds of silence).
  static const _silenceDurationThreshold = Duration(milliseconds: 1500);

  /// The server-assigned session ID for the current session.
  String? _currentSessionId;

  ConversationViewModel({
    required ConnectConversationUseCase connectUseCase,
    required StartSessionUseCase startSessionUseCase,
    required SendAudioChunkUseCase sendAudioChunkUseCase,
    required SwitchSpeakerUseCase switchSpeakerUseCase,
    required EndSessionUseCase endSessionUseCase,
    required ConversationRepository repository,
    required AuthLocalDataSource authLocalDataSource,
    required AudioRecorderService audioRecorderService,
  }) : _connectUseCase = connectUseCase,
       _startSessionUseCase = startSessionUseCase,
       _sendAudioChunkUseCase = sendAudioChunkUseCase,
       _switchSpeakerUseCase = switchSpeakerUseCase,
       _endSessionUseCase = endSessionUseCase,
       _repository = repository,
       _authLocalDataSource = authLocalDataSource,
       _audioRecorderService = audioRecorderService,
       super(const ConversationInitial());

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connects to the conversation WebSocket using the stored access token.
  ///
  /// Emits [ConversationConnecting] → [ConversationConnected]
  /// or [ConversationFailure] on error.
  Future<void> connect() async {
    emit(
      ConversationConnecting(
        messages: state.messages,
        currentSpeaker: state.currentSpeaker,
        connectionStatus: WebSocketConnectionStatus.connecting,
        sourceLanguage: state.sourceLanguage,
        targetLanguage: state.targetLanguage,
      ),
    );

    // Retrieve stored access token.
    final token = await _authLocalDataSource.getAccessToken();
    if (token == null || token.isEmpty) {
      emit(
        ConversationFailure(
          message: 'Vui lòng đăng nhập để sử dụng tính năng hội thoại.',
          messages: state.messages,
          currentSpeaker: state.currentSpeaker,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
          errorType: ConversationErrorType.authRequired,
        ),
      );
      return;
    }

    final result = _connectUseCase(
      ConnectConversationParams(accessToken: token),
    );

    result.fold(
      (failure) {
        emit(
          ConversationFailure(
            message: failure.message,
            messages: state.messages,
            currentSpeaker: state.currentSpeaker,
            sourceLanguage: state.sourceLanguage,
            targetLanguage: state.targetLanguage,
            errorType: ConversationErrorType.wsDisconnected,
          ),
        );
      },
      (eventStream) {
        _eventSubscription?.cancel();
        _eventSubscription = eventStream.listen(
          _handleEvent,
          onError: (Object error) {
            if (!isClosed) {
              emit(
                ConversationFailure(
                  message: error.toString(),
                  messages: state.messages,
                  currentSpeaker: state.currentSpeaker,
                  sourceLanguage: state.sourceLanguage,
                  targetLanguage: state.targetLanguage,
                  errorType: ConversationErrorType.wsDisconnected,
                ),
              );
            }
          },
        );

        emit(
          ConversationConnected(
            messages: state.messages,
            currentSpeaker: state.currentSpeaker,
            connectionStatus: WebSocketConnectionStatus.connected,
            sourceLanguage: state.sourceLanguage,
            targetLanguage: state.targetLanguage,
            sessionLifecycle: SessionLifecycleStatus.idle,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Session control
  // ---------------------------------------------------------------------------

  /// Starts a new conversation session with the specified languages.
  ///
  /// Delegates to [StartSessionUseCase] which sends both
  /// `session_start` and `audio_metadata` events to the backend.
  void startSession({
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    _startSessionUseCase(
      StartSessionParams(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        speaker: state.currentSpeaker,
      ),
    );
  }

  /// Transitions the UI to "recording" state and starts streaming
  /// audio from the microphone to the backend.
  ///
  /// Error handling:
  /// - [ConversationErrorType.micPermissionDenied] if permission denied.
  /// - [ConversationErrorType.recorderFailure] if recorder fails to start.
  Future<void> startListening() async {
    if (isClosed) return;

    final hasPermission = await _audioRecorderService.hasPermission();
    if (!hasPermission) {
      emit(
        ConversationFailure(
          message: 'Cần cấp quyền microphone để ghi âm.',
          messages: state.messages,
          currentSpeaker: state.currentSpeaker,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
          errorType: ConversationErrorType.micPermissionDenied,
        ),
      );
      return;
    }

    try {
      final stream = await _audioRecorderService.startStreamRecording();

      _silenceStartTime = null;
      _audioBuffer.clear();

      _audioSubscription?.cancel();
      _audioSubscription = stream.listen(
        _onAudioChunk,
        onError: (error) {
          if (!isClosed) {
            emit(
              ConversationFailure(
                message: 'Lỗi luồng ghi âm: $error',
                messages: state.messages,
                currentSpeaker: state.currentSpeaker,
                sourceLanguage: state.sourceLanguage,
                targetLanguage: state.targetLanguage,
                errorType: ConversationErrorType.recorderFailure,
              ),
            );
          }
        },
      );

      emit(
        ConversationRecording(
          messages: state.messages,
          currentSpeaker: state.currentSpeaker,
          connectionStatus: WebSocketConnectionStatus.connected,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
        ),
      );
    } catch (e) {
      emit(
        ConversationFailure(
          message: 'Lỗi khi bắt đầu ghi âm: $e',
          messages: state.messages,
          currentSpeaker: state.currentSpeaker,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
          errorType: ConversationErrorType.recorderFailure,
        ),
      );
    }
  }

  /// Processes an incoming audio chunk from the recorder.
  ///
  /// Buffers the audio into 2-second chunks via [AudioChunkBuffer],
  /// then sends each ready chunk via [SendAudioChunkUseCase].
  /// Also performs VAD to auto-stop after 1.5s of silence.
  void _onAudioChunk(Uint8List chunk) {
    // Buffer and flush 2-second chunks.
    final readyChunks = _audioBuffer.addAndFlush(chunk);
    for (final chunkToSend in readyChunks) {
      if (state is ConversationRecording) {
        final sent = _sendAudioChunkUseCase(chunkToSend);
        if (sent) {
          developer.log(
            'Sent 2s audio chunk (${chunkToSend.length} bytes)',
            name: 'ConversationVM',
          );
        }
      }
    }

    // VAD — detect silence to auto-stop.
    final volume = VadUtil.calculateNormalizedVolume(chunk);
    if (VadUtil.isSilence(volume, threshold: 0.05)) {
      _silenceStartTime ??= DateTime.now();
      if (DateTime.now().difference(_silenceStartTime!) >
          _silenceDurationThreshold) {
        developer.log(
          'Silence detected for > 1.5s, auto-stopping...',
          name: 'ConversationVM',
        );
        stopListening();
        _silenceStartTime = null;
        return;
      }
    } else {
      _silenceStartTime = null;
    }

    // Emit volume level for UI animation.
    if (!isClosed && state is ConversationRecording) {
      emit(
        ConversationRecording(
          messages: state.messages,
          currentSpeaker: state.currentSpeaker,
          connectionStatus: state.connectionStatus,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
          volumeLevel: volume,
        ),
      );
    }
  }

  /// Stops the current recording and sends `end_utterance` to the server.
  ///
  /// Flushes any remaining buffered audio before signaling end.
  /// Emits [ConversationProcessing] while waiting for the translation result.
  Future<void> stopListening({bool finalizeUtterance = true}) async {
    if (isClosed) return;

    _silenceStartTime = null;

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (_audioRecorderService.isRecording) {
      await _audioRecorderService.stopStreamRecording();
    }

    // Send any remaining audio in the buffer before ending utterance.
    final remaining = _audioBuffer.flushRemaining();
    if (remaining != null) {
      final sent = _sendAudioChunkUseCase(remaining);
      if (sent) {
        developer.log(
          'Sent remaining audio (${remaining.length} bytes)',
          name: 'ConversationVM',
        );
      }
    }

    if (finalizeUtterance) {
      _repository.endUtterance();
      emit(
        ConversationProcessing(
          messages: state.messages,
          currentSpeaker: state.currentSpeaker,
          connectionStatus: WebSocketConnectionStatus.connected,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
        ),
      );
    }
  }

  /// Switches the active speaker between A and B.
  ///
  /// Delegates to [SwitchSpeakerUseCase] and re-emits the current
  /// state with the updated speaker.
  void switchSpeaker() {
    if (isClosed) return;
    final newSpeaker = state.currentSpeaker == ConversationSpeaker.speakerA
        ? ConversationSpeaker.speakerB
        : ConversationSpeaker.speakerA;

    _switchSpeakerUseCase(newSpeaker);
    _emitWithUpdatedSpeaker(newSpeaker);
  }

  /// Ends the conversation session and stops continuous recording.
  ///
  /// Delegates to [EndSessionUseCase].
  Future<void> endSession() async {
    if (isClosed) return;
    await stopListening(finalizeUtterance: false);
    _endSessionUseCase();
    _currentSessionId = null;
    emit(
      ConversationConnected(
        messages: state.messages,
        currentSpeaker: state.currentSpeaker,
        connectionStatus: WebSocketConnectionStatus.connected,
        sourceLanguage: state.sourceLanguage,
        targetLanguage: state.targetLanguage,
        sessionLifecycle: SessionLifecycleStatus.ended,
      ),
    );
  }

  /// Disconnects and resets to initial state.
  Future<void> disconnect() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (_audioRecorderService.isRecording) {
      await _audioRecorderService.stopStreamRecording();
    }

    _eventSubscription?.cancel();
    _eventSubscription = null;
    _audioBuffer.clear();
    _currentSessionId = null;
    _repository.disconnect();

    if (!isClosed) {
      emit(const ConversationInitial());
    }
  }

  /// Updates the source and target languages.
  void setLanguages({
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    if (isClosed) return;
    emit(
      ConversationConnected(
        messages: state.messages,
        currentSpeaker: state.currentSpeaker,
        connectionStatus: state.connectionStatus,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        sessionLifecycle: state.sessionLifecycle,
      ),
    );
  }

  /// Clears all messages from the conversation.
  void clearMessages() {
    if (isClosed) return;
    emit(
      ConversationConnected(
        messages: const [],
        currentSpeaker: state.currentSpeaker,
        connectionStatus: state.connectionStatus,
        sourceLanguage: state.sourceLanguage,
        targetLanguage: state.targetLanguage,
        sessionLifecycle: state.sessionLifecycle,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Event handling
  // ---------------------------------------------------------------------------

  void _handleEvent(ConversationEvent event) {
    if (isClosed) return;

    switch (event) {
      case ConversationSessionStarted(:final sessionId):
        _currentSessionId = sessionId;
        emit(
          ConversationConnected(
            messages: state.messages,
            currentSpeaker: state.currentSpeaker,
            connectionStatus: WebSocketConnectionStatus.connected,
            sourceLanguage: state.sourceLanguage,
            targetLanguage: state.targetLanguage,
            sessionId: sessionId,
            sessionLifecycle: SessionLifecycleStatus.ready,
          ),
        );
        // Auto-start listening once session starts.
        startListening();

      case ConversationMetadataAcknowledged():
        // No state change needed — metadata is acknowledged.
        break;

      case ConversationTranslationReceived(:final message):
        final updatedMessages = List<ConversationMessage>.of(state.messages)
          ..add(message);
        emit(
          ConversationConnected(
            messages: updatedMessages,
            currentSpeaker: state.currentSpeaker,
            connectionStatus: WebSocketConnectionStatus.connected,
            sourceLanguage: state.sourceLanguage,
            targetLanguage: state.targetLanguage,
            sessionId: _currentSessionId,
            sessionLifecycle: SessionLifecycleStatus.ready,
          ),
        );
        // Auto-resume recording for continuous conversation.
        _autoResumeListening();

      case ConversationErrorEvent(:final code, :final message):
        emit(
          ConversationFailure(
            message: '[$code] $message',
            messages: state.messages,
            currentSpeaker: state.currentSpeaker,
            sourceLanguage: state.sourceLanguage,
            targetLanguage: state.targetLanguage,
            errorType: ConversationErrorType.backendError,
          ),
        );

      case ConversationPong():
        // Keepalive — no state change needed.
        break;

      case ConversationConnectionChanged(:final status):
        if (status == WebSocketConnectionStatus.disconnected ||
            status == WebSocketConnectionStatus.error) {
          emit(
            ConversationDisconnected(
              messages: state.messages,
              currentSpeaker: state.currentSpeaker,
              sourceLanguage: state.sourceLanguage,
              targetLanguage: state.targetLanguage,
              reason: status == WebSocketConnectionStatus.error
                  ? 'Lỗi kết nối WebSocket'
                  : 'Mất kết nối',
            ),
          );
        } else if (status == WebSocketConnectionStatus.reconnecting) {
          emit(
            ConversationConnecting(
              messages: state.messages,
              currentSpeaker: state.currentSpeaker,
              connectionStatus: WebSocketConnectionStatus.reconnecting,
              sourceLanguage: state.sourceLanguage,
              targetLanguage: state.targetLanguage,
            ),
          );
        }
    }
  }

  /// Automatically resumes recording after receiving a translation result.
  ///
  /// This enables continuous conversation mode: after each utterance
  /// is translated, the mic turns on again for the next one.
  Future<void> _autoResumeListening() async {
    if (isClosed) return;
    if (_currentSessionId == null) return;
    if (state.connectionStatus != WebSocketConnectionStatus.connected) return;

    // Small delay to avoid overlapping with UI state transitions.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!isClosed &&
        state is ConversationConnected &&
        _currentSessionId != null) {
      startListening();
    }
  }

  void _emitWithUpdatedSpeaker(ConversationSpeaker newSpeaker) {
    switch (state) {
      case ConversationConnected():
        emit(
          ConversationConnected(
            messages: state.messages,
            currentSpeaker: newSpeaker,
            connectionStatus: state.connectionStatus,
            sourceLanguage: state.sourceLanguage,
            targetLanguage: state.targetLanguage,
            sessionLifecycle: state.sessionLifecycle,
          ),
        );
      case ConversationRecording():
        emit(
          ConversationRecording(
            messages: state.messages,
            currentSpeaker: newSpeaker,
            connectionStatus: state.connectionStatus,
            sourceLanguage: state.sourceLanguage,
            targetLanguage: state.targetLanguage,
          ),
        );
      default:
        emit(
          ConversationConnected(
            messages: state.messages,
            currentSpeaker: newSpeaker,
            connectionStatus: state.connectionStatus,
            sourceLanguage: state.sourceLanguage,
            targetLanguage: state.targetLanguage,
            sessionLifecycle: state.sessionLifecycle,
          ),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> close() async {
    await _audioSubscription?.cancel();
    if (_audioRecorderService.isRecording) {
      await _audioRecorderService.stopStreamRecording();
    }
    await _eventSubscription?.cancel();
    _audioBuffer.clear();
    _currentSessionId = null;
    _repository.disconnect();
    return super.close();
  }
}
