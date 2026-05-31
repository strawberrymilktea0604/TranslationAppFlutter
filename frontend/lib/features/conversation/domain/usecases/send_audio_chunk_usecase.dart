import 'dart:typed_data';

import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';
import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';

/// UseCase that sends a binary audio chunk to the conversation backend.
///
/// Validates the WebSocket connection status before sending.
/// Returns `true` if the chunk was sent, `false` if the connection
/// was not in a valid state.
///
/// Clean Architecture flow:
///   ConversationViewModel → SendAudioChunkUseCase → ConversationRepository
class SendAudioChunkUseCase {
  final ConversationRepository _repository;

  const SendAudioChunkUseCase(this._repository);

  /// Sends [chunk] to the server if connected.
  ///
  /// Returns `true` if the chunk was dispatched to the WebSocket,
  /// `false` if the connection was not ready.
  bool call(Uint8List chunk) {
    if (_repository.connectionStatus != WebSocketConnectionStatus.connected) {
      return false;
    }
    _repository.sendAudioChunk(chunk);
    return true;
  }
}
