import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/conversation/data/datasources/conversation_remote_datasource.dart';
import 'package:frontend/features/conversation/data/repositories/conversation_repository_impl.dart';
import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';

class _FakeConversationRemoteDataSource
    implements ConversationRemoteDataSource {
  final _messages = StreamController<dynamic>.broadcast();
  final _statuses = StreamController<WebSocketConnectionStatus>.broadcast();

  @override
  WebSocketConnectionStatus connectionStatus =
      WebSocketConnectionStatus.disconnected;

  @override
  Stream<dynamic> get messageStream => _messages.stream;

  @override
  Stream<WebSocketConnectionStatus> get statusStream => _statuses.stream;

  @override
  void connect(String wsUrl) {
    connectionStatus = WebSocketConnectionStatus.connected;
  }

  void emitJson(Map<String, dynamic> data) {
    _messages.add(jsonEncode(data));
  }

  @override
  Future<void> disconnect() async {
    connectionStatus = WebSocketConnectionStatus.disconnected;
  }

  @override
  Future<void> dispose() async {
    await _messages.close();
    await _statuses.close();
  }

  @override
  void sendBytes(Uint8List data) {}

  @override
  void sendJson(Map<String, dynamic> data) {}
}

Map<String, dynamic> _translationEvent(String event, int messageId) => {
  'event': event,
  'message_id': messageId,
  'session_id': 'session-1',
  'speaker': 'SPEAKER_A',
  'source_text': 'xin chao',
  'translated_text': 'hello',
  'source_language': 'vi',
  'target_language': 'en',
  'is_cached': false,
  'response_time_ms': 25.5,
  'timestamp': '2026-05-31T12:00:00Z',
};

void main() {
  test(
    'parses final_translation and legacy translation_result events',
    () async {
      final dataSource = _FakeConversationRemoteDataSource();
      final repository = ConversationRepositoryImpl(
        dataSource: dataSource,
        baseApiUrl: 'http://localhost:8000/api/v1',
      );

      final translations = repository
          .connect('token')
          .where((event) => event is ConversationTranslationReceived)
          .cast<ConversationTranslationReceived>()
          .take(2);
      final expectation = expectLater(
        translations,
        emitsInOrder([
          isA<ConversationTranslationReceived>().having(
            (event) => event.message.id,
            'final message id',
            '101',
          ),
          isA<ConversationTranslationReceived>().having(
            (event) => event.message.id,
            'legacy message id',
            '102',
          ),
        ]),
      );

      dataSource.emitJson(_translationEvent('final_translation', 101));
      dataSource.emitJson(_translationEvent('translation_result', 102));

      await expectation;
      repository.disconnect();
      await dataSource.dispose();
    },
  );
}
