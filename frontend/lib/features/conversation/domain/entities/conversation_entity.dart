import 'package:equatable/equatable.dart';

/// Speaker roles in a two-way conversation.
///
/// Maps to backend enum: `SPEAKER_A`, `SPEAKER_B`.
enum ConversationSpeaker {
  speakerA('SPEAKER_A'),
  speakerB('SPEAKER_B');

  const ConversationSpeaker(this.value);

  /// Wire value sent to/from the backend WebSocket.
  final String value;

  /// Parse from backend string, defaulting to [speakerA].
  static ConversationSpeaker fromString(String? value) {
    if (value == null) return speakerA;
    return ConversationSpeaker.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => speakerA,
    );
  }
}

/// WebSocket connection status.
enum WebSocketConnectionStatus {
  /// Not connected.
  disconnected,

  /// Handshake in progress.
  connecting,

  /// Connected and ready.
  connected,

  /// Lost connection, attempting to reconnect.
  reconnecting,

  /// Unrecoverable error.
  error,
}

/// Session lifecycle status matching backend `SessionStatus`.
enum ConversationSessionStatus {
  /// No active session.
  idle,

  /// Microphone active, capturing audio.
  recording,

  /// STT + translation in progress on server.
  processing,

  /// Session has ended.
  ended,
}

/// Pure Dart entity representing a single message in a conversation.
///
/// Contains the STT-extracted source text, its translation, speaker info,
/// and metadata. No framework dependency — belongs to the Domain layer.
class ConversationMessage extends Equatable {
  /// Unique identifier for this message.
  final String id;

  /// Which speaker produced this utterance.
  final ConversationSpeaker speaker;

  /// Text extracted from audio via Speech-to-Text.
  final String sourceText;

  /// Translated text in the target language.
  final String translatedText;

  /// Source language code (ISO 639-1).
  final String sourceLanguage;

  /// Target language code (ISO 639-1).
  final String targetLanguage;

  /// When this message was received.
  final DateTime timestamp;

  /// Whether the translation result came from server cache.
  final bool isCached;

  /// Server-side processing time in milliseconds.
  final double responseTimeMs;

  const ConversationMessage({
    required this.id,
    required this.speaker,
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
    this.isCached = false,
    this.responseTimeMs = 0.0,
  });

  @override
  List<Object?> get props => [
        id,
        speaker,
        sourceText,
        translatedText,
        sourceLanguage,
        targetLanguage,
        timestamp,
        isCached,
        responseTimeMs,
      ];
}

// ---------------------------------------------------------------------------
// WebSocket event hierarchy — parsed from raw WS messages by the Data layer.
// ---------------------------------------------------------------------------

/// Base class for all events received from the conversation WebSocket.
sealed class ConversationEvent {
  const ConversationEvent();
}

/// Session was successfully started on the server.
final class ConversationSessionStarted extends ConversationEvent {
  final String sessionId;
  final String status;

  const ConversationSessionStarted({
    required this.sessionId,
    required this.status,
  });
}

/// Audio metadata was acknowledged by the server.
final class ConversationMetadataAcknowledged extends ConversationEvent {
  final String sessionId;

  const ConversationMetadataAcknowledged({required this.sessionId});
}

/// A translation result was received.
final class ConversationTranslationReceived extends ConversationEvent {
  final ConversationMessage message;

  const ConversationTranslationReceived({required this.message});
}

/// An error event from the server.
final class ConversationErrorEvent extends ConversationEvent {
  final String code;
  final String message;

  const ConversationErrorEvent({
    required this.code,
    required this.message,
  });
}

/// Pong response (keepalive acknowledgement).
final class ConversationPong extends ConversationEvent {
  const ConversationPong();
}

/// WebSocket connection status changed.
final class ConversationConnectionChanged extends ConversationEvent {
  final WebSocketConnectionStatus status;

  const ConversationConnectionChanged({required this.status});
}
