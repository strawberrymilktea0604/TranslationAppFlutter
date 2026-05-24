part of 'conversation_cubit.dart';

/// Base sealed class for conversation states.
///
/// Uses sealed class approach for type safety and exhaustiveness
/// (per Bloc rules §Modeling State rule 7).
///
/// Shared properties are stored in the base class so all states
/// can carry the current messages, speaker, and language config.
sealed class ConversationState {
  /// All messages exchanged in the current conversation.
  final List<ConversationMessage> messages;

  /// Currently active speaker.
  final ConversationSpeaker currentSpeaker;

  /// Current WebSocket connection status.
  final WebSocketConnectionStatus connectionStatus;

  /// Source language code (ISO 639-1).
  final String sourceLanguage;

  /// Target language code (ISO 639-1).
  final String targetLanguage;

  const ConversationState({
    this.messages = const [],
    this.currentSpeaker = ConversationSpeaker.speakerA,
    this.connectionStatus = WebSocketConnectionStatus.disconnected,
    this.sourceLanguage = 'vi',
    this.targetLanguage = 'en',
  });
}

/// Idle — no conversation started, not connected.
final class ConversationInitial extends ConversationState {
  const ConversationInitial({
    super.sourceLanguage,
    super.targetLanguage,
  });
}

/// WebSocket connection is being established or reconnecting.
final class ConversationConnecting extends ConversationState {
  const ConversationConnecting({
    required super.messages,
    required super.currentSpeaker,
    required super.connectionStatus,
    required super.sourceLanguage,
    required super.targetLanguage,
  });
}

/// Connected and idle — ready to start/continue the conversation.
final class ConversationConnected extends ConversationState {
  /// The server-assigned session ID (set after session_start ack).
  final String? sessionId;

  const ConversationConnected({
    required super.messages,
    required super.currentSpeaker,
    required super.connectionStatus,
    required super.sourceLanguage,
    required super.targetLanguage,
    this.sessionId,
  });
}

/// Microphone is active — user is speaking.
final class ConversationRecording extends ConversationState {
  const ConversationRecording({
    required super.messages,
    required super.currentSpeaker,
    required super.connectionStatus,
    required super.sourceLanguage,
    required super.targetLanguage,
  });
}

/// Audio uploaded, STT + translation in progress on server.
final class ConversationProcessing extends ConversationState {
  const ConversationProcessing({
    required super.messages,
    required super.currentSpeaker,
    required super.connectionStatus,
    required super.sourceLanguage,
    required super.targetLanguage,
  });
}

/// WebSocket disconnected unexpectedly.
final class ConversationDisconnected extends ConversationState {
  /// Human-readable reason for disconnection.
  final String reason;

  const ConversationDisconnected({
    required super.messages,
    required super.currentSpeaker,
    required super.sourceLanguage,
    required super.targetLanguage,
    this.reason = 'Mất kết nối',
  }) : super(connectionStatus: WebSocketConnectionStatus.disconnected);
}

/// An error occurred.
final class ConversationFailure extends ConversationState {
  /// Error message for display.
  final String message;

  const ConversationFailure({
    required this.message,
    required super.messages,
    required super.currentSpeaker,
    required super.sourceLanguage,
    required super.targetLanguage,
  }) : super(connectionStatus: WebSocketConnectionStatus.error);
}
