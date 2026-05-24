import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:frontend/features/conversation/data/datasources/conversation_remote_datasource.dart';
import 'package:frontend/features/conversation/data/models/conversation_message_model.dart';
import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';
import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';

/// Implementation of [ConversationRepository].
///
/// Manages the conversation WebSocket lifecycle and maps raw WS
/// messages to domain [ConversationEvent]s.
///
/// Clean Architecture: Data layer — depends on [ConversationRemoteDataSource]
/// and produces domain entities/events consumed by the Cubit.
class ConversationRepositoryImpl implements ConversationRepository {
  final ConversationRemoteDataSource _dataSource;
  final String _baseApiUrl;

  /// Broadcast controller that merges WS messages + connection status
  /// into a single [ConversationEvent] stream.
  final _eventController = StreamController<ConversationEvent>.broadcast();
  StreamSubscription<dynamic>? _messageSubscription;
  StreamSubscription<WebSocketConnectionStatus>? _statusSubscription;

  ConversationRepositoryImpl({
    required ConversationRemoteDataSource dataSource,
    required String baseApiUrl,
  })  : _dataSource = dataSource,
        _baseApiUrl = baseApiUrl;

  @override
  WebSocketConnectionStatus get connectionStatus =>
      _dataSource.connectionStatus;

  @override
  Stream<ConversationEvent> connect(String accessToken) {
    // Build the WS URL from the REST API base URL.
    // e.g. http://host:8000/api/v1 → ws://host:8000/api/v1/ws/conversation
    final wsUrl = _baseApiUrl
        .replaceFirst(RegExp(r'^http'), 'ws')
        .replaceFirst(RegExp(r'/api/v1$'), '/api/v1');
    final fullUrl = '$wsUrl/ws/conversation?token=$accessToken';

    _dataSource.connect(fullUrl);

    // Listen to raw WS messages and parse into domain events.
    _messageSubscription?.cancel();
    _messageSubscription = _dataSource.messageStream.listen(
      _handleRawMessage,
      onError: (Object error) {
        if (!_eventController.isClosed) {
          _eventController.add(ConversationErrorEvent(
            code: 'WS_STREAM_ERROR',
            message: error.toString(),
          ));
        }
      },
    );

    // Listen to connection status changes.
    _statusSubscription?.cancel();
    _statusSubscription = _dataSource.statusStream.listen((status) {
      if (!_eventController.isClosed) {
        _eventController.add(
          ConversationConnectionChanged(status: status),
        );
      }
    });

    return _eventController.stream;
  }

  void _handleRawMessage(dynamic raw) {
    if (raw is! String) {
      // Binary frames are server → client only for future features;
      // currently the server only sends JSON text frames.
      return;
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final event = data['event'] as String?;

      switch (event) {
        case 'session_started':
          _eventController.add(ConversationSessionStarted(
            sessionId: data['session_id'] as String? ?? '',
            status: data['status'] as String? ?? '',
          ));

        case 'audio_metadata_ack':
          _eventController.add(ConversationMetadataAcknowledged(
            sessionId: data['session_id'] as String? ?? '',
          ));

        case 'translation_result':
          final model = ConversationMessageModel.fromJson(data);
          _eventController.add(
            ConversationTranslationReceived(message: model.toEntity()),
          );

        case 'error':
          _eventController.add(ConversationErrorEvent(
            code: data['code'] as String? ?? 'UNKNOWN',
            message: data['message'] as String? ?? 'Unknown error',
          ));

        case 'pong':
          _eventController.add(const ConversationPong());

        default:
          developer.log(
            'Unknown event: $event',
            name: 'ConversationRepo',
          );
      }
    } catch (e) {
      developer.log(
        'Parse error: $e',
        name: 'ConversationRepo',
      );
    }
  }

  @override
  void startSession({
    required String sourceLanguage,
    required String targetLanguage,
    ConversationSpeaker speaker = ConversationSpeaker.speakerA,
  }) {
    _dataSource.sendJson({
      'event': 'session_start',
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'speaker': speaker.value,
    });
  }

  @override
  void sendAudioMetadata({
    required int sampleRate,
    required String audioFormat,
    required ConversationSpeaker speaker,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    _dataSource.sendJson({
      'event': 'audio_metadata',
      'sample_rate': sampleRate,
      'audio_format': audioFormat,
      'speaker': speaker.value,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
    });
  }

  @override
  void sendAudioChunk(Uint8List chunk) {
    _dataSource.sendBytes(chunk);
  }

  @override
  void endUtterance() {
    _dataSource.sendJson({'event': 'end_utterance'});
  }

  @override
  void changeSpeaker(ConversationSpeaker speaker) {
    _dataSource.sendJson({
      'event': 'speaker_changed',
      'speaker': speaker.value,
    });
  }

  @override
  void endSession() {
    _dataSource.sendJson({'event': 'session_end'});
  }

  @override
  void disconnect() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _dataSource.disconnect();
  }

  /// Dispose all resources. Call when the repository is no longer needed.
  Future<void> dispose() async {
    disconnect();
    await _eventController.close();
    await _dataSource.dispose();
  }
}
