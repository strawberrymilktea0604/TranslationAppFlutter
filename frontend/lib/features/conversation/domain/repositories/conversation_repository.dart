import 'dart:typed_data';

import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';

/// Abstract repository interface for conversation WebSocket operations.
///
/// Defines the contract between the Domain and Data layers.
/// The implementation handles WebSocket connection management,
/// message serialization, and event stream parsing.
///
/// Clean Architecture: Domain layer — no framework dependency.
abstract class ConversationRepository {
  /// Opens a WebSocket connection to the conversation endpoint.
  ///
  /// Returns a broadcast [Stream] of [ConversationEvent]s parsed from
  /// server messages. The stream emits:
  /// - [ConversationSessionStarted] after successful `session_start`.
  /// - [ConversationTranslationReceived] for each `final_translation`.
  /// - [ConversationErrorEvent] for server-side errors.
  /// - [ConversationConnectionChanged] on connection status changes.
  ///
  /// Throws [ServerFailure] if the connection cannot be established.
  Stream<ConversationEvent> connect(String accessToken);

  /// Sends a `session_start` event to begin a new conversation session.
  ///
  /// Must be called after [connect] succeeds.
  void startSession({
    required String sourceLanguage,
    required String targetLanguage,
    ConversationSpeaker speaker = ConversationSpeaker.speakerA,
  });

  /// Sends `audio_metadata` to configure audio processing parameters.
  ///
  /// Must be called after [startSession] and before sending audio chunks.
  void sendAudioMetadata({
    required int sampleRate,
    required String audioFormat,
    required ConversationSpeaker speaker,
    required String sourceLanguage,
    required String targetLanguage,
  });

  /// Sends a binary audio chunk (raw PCM data) to the server.
  ///
  /// Audio must be in the format specified by [sendAudioMetadata].
  void sendAudioChunk(Uint8List chunk);

  /// Signals that the current utterance has ended.
  ///
  /// The server will flush the PCM buffer, run STT, translate,
  /// and return a `final_translation` event.
  void endUtterance();

  /// Changes the active speaker mid-session.
  void changeSpeaker(ConversationSpeaker speaker);

  /// Ends the current session gracefully.
  ///
  /// The server will clean up session state and close the connection.
  void endSession();

  /// Disconnects the WebSocket connection.
  ///
  /// Should be called when leaving the conversation screen.
  void disconnect();

  /// Current WebSocket connection status.
  WebSocketConnectionStatus get connectionStatus;
}
