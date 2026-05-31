part of 'conversation_viewmodel.dart';

/// Error classification for the conversation feature.
///
/// Allows the UI layer to display contextually appropriate error
/// messages and actions (e.g. "open Settings" for permission errors).
enum ConversationErrorType {
  /// Microphone permission was denied by the user.
  micPermissionDenied,

  /// WebSocket connection was lost unexpectedly.
  wsDisconnected,

  /// Audio recorder failed to start or stream.
  recorderFailure,

  /// Server returned an error event.
  backendError,

  /// User is not authenticated (no token).
  authRequired,

  /// Catch-all for unexpected errors.
  unknown,
}

/// Session lifecycle status used by the UI to show appropriate
/// indicators and controls.
enum SessionLifecycleStatus {
  /// No active session.
  idle,

  /// Session created, ready to record.
  ready,

  /// Microphone active, capturing audio.
  recording,

  /// Audio sent, waiting for STT + translation.
  processing,

  /// Session ended by user.
  ended,
}

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

  /// Current microphone volume level (0.0 to 1.0) when recording.
  final double volumeLevel;

  /// Session lifecycle status for UI indicators.
  final SessionLifecycleStatus sessionLifecycle;

  const ConversationState({
    this.messages = const [],
    this.currentSpeaker = ConversationSpeaker.speakerA,
    this.connectionStatus = WebSocketConnectionStatus.disconnected,
    this.sourceLanguage = 'vi',
    this.targetLanguage = 'en',
    this.volumeLevel = 0.0,
    this.sessionLifecycle = SessionLifecycleStatus.idle,
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
    super.sessionLifecycle,
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
    super.sessionLifecycle,
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
    super.volumeLevel = 0.0,
  }) : super(sessionLifecycle: SessionLifecycleStatus.recording);
}

/// Audio uploaded, STT + translation in progress on server.
final class ConversationProcessing extends ConversationState {
  const ConversationProcessing({
    required super.messages,
    required super.currentSpeaker,
    required super.connectionStatus,
    required super.sourceLanguage,
    required super.targetLanguage,
  }) : super(sessionLifecycle: SessionLifecycleStatus.processing);
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
    super.sessionLifecycle,
    this.reason = 'Mất kết nối',
  }) : super(connectionStatus: WebSocketConnectionStatus.disconnected);
}

/// An error occurred.
final class ConversationFailure extends ConversationState {
  /// Error message for display.
  final String message;

  /// Classified error type for contextual UI handling.
  final ConversationErrorType errorType;

  const ConversationFailure({
    required this.message,
    required super.messages,
    required super.currentSpeaker,
    required super.sourceLanguage,
    required super.targetLanguage,
    this.errorType = ConversationErrorType.unknown,
    super.sessionLifecycle,
  }) : super(connectionStatus: WebSocketConnectionStatus.error);
}
