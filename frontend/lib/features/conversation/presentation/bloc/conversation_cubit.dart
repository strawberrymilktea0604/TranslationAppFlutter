import 'dart:async';

import 'package:bloc/bloc.dart';

import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';
import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:frontend/features/conversation/domain/usecases/connect_conversation_usecase.dart';

part 'conversation_state.dart';

/// Cubit managing the real-time conversation translation session.
///
/// Handles the full lifecycle:
///   connect → startSession → recording → processing → result → repeat
///
/// Clean Architecture flow:
///   UI → ConversationCubit → UseCase/Repository → DataSource (WebSocket)
///
/// The Cubit listens to the [ConversationEvent] stream from the repository
/// and emits appropriate [ConversationState] subclasses. The UI rebuilds
/// via [BlocBuilder] / [BlocConsumer].
class ConversationCubit extends Cubit<ConversationState> {
  final ConnectConversationUseCase _connectUseCase;
  final ConversationRepository _repository;
  final AuthLocalDataSource _authLocalDataSource;

  StreamSubscription<ConversationEvent>? _eventSubscription;

  ConversationCubit({
    required ConnectConversationUseCase connectUseCase,
    required ConversationRepository repository,
    required AuthLocalDataSource authLocalDataSource,
  })  : _connectUseCase = connectUseCase,
        _repository = repository,
        _authLocalDataSource = authLocalDataSource,
        super(const ConversationInitial());

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connects to the conversation WebSocket using the stored access token.
  ///
  /// Emits [ConversationConnecting] → [ConversationConnected]
  /// or [ConversationFailure] on error.
  Future<void> connect() async {
    emit(ConversationConnecting(
      messages: state.messages,
      currentSpeaker: state.currentSpeaker,
      connectionStatus: WebSocketConnectionStatus.connecting,
      sourceLanguage: state.sourceLanguage,
      targetLanguage: state.targetLanguage,
    ));

    // Retrieve stored access token.
    final token = await _authLocalDataSource.getAccessToken();
    if (token == null || token.isEmpty) {
      emit(ConversationFailure(
        message: 'Vui lòng đăng nhập để sử dụng tính năng hội thoại.',
        messages: state.messages,
        currentSpeaker: state.currentSpeaker,
        sourceLanguage: state.sourceLanguage,
        targetLanguage: state.targetLanguage,
      ));
      return;
    }

    final result = _connectUseCase(
      ConnectConversationParams(accessToken: token),
    );

    result.fold(
      (failure) {
        emit(ConversationFailure(
          message: failure.message,
          messages: state.messages,
          currentSpeaker: state.currentSpeaker,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
        ));
      },
      (eventStream) {
        _eventSubscription?.cancel();
        _eventSubscription = eventStream.listen(
          _handleEvent,
          onError: (Object error) {
            if (!isClosed) {
              emit(ConversationFailure(
                message: error.toString(),
                messages: state.messages,
                currentSpeaker: state.currentSpeaker,
                sourceLanguage: state.sourceLanguage,
                targetLanguage: state.targetLanguage,
              ));
            }
          },
        );

        emit(ConversationConnected(
          messages: state.messages,
          currentSpeaker: state.currentSpeaker,
          connectionStatus: WebSocketConnectionStatus.connected,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
        ));
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Session control
  // ---------------------------------------------------------------------------

  /// Starts a new conversation session with the specified languages.
  void startSession({
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    _repository.startSession(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      speaker: state.currentSpeaker,
    );

    // Also send audio metadata for the default recording configuration.
    _repository.sendAudioMetadata(
      sampleRate: 16000,
      audioFormat: 'pcm_s16le',
      speaker: state.currentSpeaker,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }

  /// Transitions the UI to "recording" state.
  ///
  /// This signals the UI to show the recording animation.
  /// Actual microphone integration will be done in a future task.
  void startListening() {
    if (isClosed) return;
    emit(ConversationRecording(
      messages: state.messages,
      currentSpeaker: state.currentSpeaker,
      connectionStatus: WebSocketConnectionStatus.connected,
      sourceLanguage: state.sourceLanguage,
      targetLanguage: state.targetLanguage,
    ));
  }

  /// Stops the current recording and sends `end_utterance` to the server.
  ///
  /// Emits [ConversationProcessing] while waiting for the translation result.
  void stopListening() {
    if (isClosed) return;
    _repository.endUtterance();
    emit(ConversationProcessing(
      messages: state.messages,
      currentSpeaker: state.currentSpeaker,
      connectionStatus: WebSocketConnectionStatus.connected,
      sourceLanguage: state.sourceLanguage,
      targetLanguage: state.targetLanguage,
    ));
  }

  /// Switches the active speaker between A and B.
  void switchSpeaker() {
    if (isClosed) return;
    final newSpeaker = state.currentSpeaker == ConversationSpeaker.speakerA
        ? ConversationSpeaker.speakerB
        : ConversationSpeaker.speakerA;

    _repository.changeSpeaker(newSpeaker);

    // Re-emit current state type with updated speaker.
    _emitWithUpdatedSpeaker(newSpeaker);
  }

  /// Ends the conversation session.
  void endSession() {
    if (isClosed) return;
    _repository.endSession();
    emit(ConversationConnected(
      messages: state.messages,
      currentSpeaker: state.currentSpeaker,
      connectionStatus: WebSocketConnectionStatus.connected,
      sourceLanguage: state.sourceLanguage,
      targetLanguage: state.targetLanguage,
    ));
  }

  /// Disconnects and resets to initial state.
  void disconnect() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
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
    emit(ConversationConnected(
      messages: state.messages,
      currentSpeaker: state.currentSpeaker,
      connectionStatus: state.connectionStatus,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    ));
  }

  /// Clears all messages from the conversation.
  void clearMessages() {
    if (isClosed) return;
    emit(ConversationConnected(
      messages: const [],
      currentSpeaker: state.currentSpeaker,
      connectionStatus: state.connectionStatus,
      sourceLanguage: state.sourceLanguage,
      targetLanguage: state.targetLanguage,
    ));
  }

  // ---------------------------------------------------------------------------
  // Event handling
  // ---------------------------------------------------------------------------

  void _handleEvent(ConversationEvent event) {
    if (isClosed) return;

    switch (event) {
      case ConversationSessionStarted():
        emit(ConversationConnected(
          messages: state.messages,
          currentSpeaker: state.currentSpeaker,
          connectionStatus: WebSocketConnectionStatus.connected,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
          sessionId: event.sessionId,
        ));

      case ConversationMetadataAcknowledged():
        // No state change needed — metadata is acknowledged.
        break;

      case ConversationTranslationReceived(:final message):
        final updatedMessages = List<ConversationMessage>.of(state.messages)
          ..add(message);
        emit(ConversationConnected(
          messages: updatedMessages,
          currentSpeaker: state.currentSpeaker,
          connectionStatus: WebSocketConnectionStatus.connected,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
        ));

      case ConversationErrorEvent(:final code, :final message):
        emit(ConversationFailure(
          message: '[$code] $message',
          messages: state.messages,
          currentSpeaker: state.currentSpeaker,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
        ));

      case ConversationPong():
        // Keepalive — no state change needed.
        break;

      case ConversationConnectionChanged(:final status):
        if (status == WebSocketConnectionStatus.disconnected ||
            status == WebSocketConnectionStatus.error) {
          emit(ConversationDisconnected(
            messages: state.messages,
            currentSpeaker: state.currentSpeaker,
            sourceLanguage: state.sourceLanguage,
            targetLanguage: state.targetLanguage,
            reason: status == WebSocketConnectionStatus.error
                ? 'Lỗi kết nối WebSocket'
                : 'Mất kết nối',
          ));
        } else if (status == WebSocketConnectionStatus.reconnecting) {
          emit(ConversationConnecting(
            messages: state.messages,
            currentSpeaker: state.currentSpeaker,
            connectionStatus: WebSocketConnectionStatus.reconnecting,
            sourceLanguage: state.sourceLanguage,
            targetLanguage: state.targetLanguage,
          ));
        }
    }
  }

  void _emitWithUpdatedSpeaker(ConversationSpeaker newSpeaker) {
    switch (state) {
      case ConversationConnected():
        emit(ConversationConnected(
          messages: state.messages,
          currentSpeaker: newSpeaker,
          connectionStatus: state.connectionStatus,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
        ));
      case ConversationRecording():
        emit(ConversationRecording(
          messages: state.messages,
          currentSpeaker: newSpeaker,
          connectionStatus: state.connectionStatus,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
        ));
      default:
        // For other states, just update via Connected.
        emit(ConversationConnected(
          messages: state.messages,
          currentSpeaker: newSpeaker,
          connectionStatus: state.connectionStatus,
          sourceLanguage: state.sourceLanguage,
          targetLanguage: state.targetLanguage,
        ));
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    return super.close();
  }
}
