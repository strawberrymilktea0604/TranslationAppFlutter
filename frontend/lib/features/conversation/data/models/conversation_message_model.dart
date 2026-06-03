import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';

/// Data model for parsing `final_translation` events from the
/// conversation WebSocket.
///
/// Maps raw JSON → [ConversationMessage] entity.
/// Data layer only — the Presentation layer works exclusively with entities.
class ConversationMessageModel {
  final String sessionId;
  final int? messageId;
  final String sourceText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final String? speaker;
  final bool isCached;
  final double responseTimeMs;
  final DateTime? timestamp;

  const ConversationMessageModel({
    required this.sessionId,
    this.messageId,
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.speaker,
    this.isCached = false,
    this.responseTimeMs = 0.0,
    this.timestamp,
  });

  /// Creates a model from the raw JSON map received via WebSocket.
  ///
  /// Expected JSON shape (from backend `final_translation` event):
  /// ```json
  /// {
  ///   "event": "final_translation",
  ///   "message_id": 123,
  ///   "session_id": "...",
  ///   "source_text": "...",
  ///   "translated_text": "...",
  ///   "source_language": "vi",
  ///   "target_language": "en",
  ///   "speaker": "SPEAKER_A",
  ///   "is_cached": false,
  ///   "response_time_ms": 123.45
  /// }
  /// ```
  factory ConversationMessageModel.fromJson(Map<String, dynamic> json) {
    return ConversationMessageModel(
      sessionId: json['session_id'] as String? ?? '',
      messageId: json['message_id'] as int?,
      sourceText: json['source_text'] as String? ?? '',
      translatedText: json['translated_text'] as String? ?? '',
      sourceLanguage: json['source_language'] as String? ?? '',
      targetLanguage: json['target_language'] as String? ?? '',
      speaker: json['speaker'] as String?,
      isCached: json['is_cached'] as bool? ?? false,
      responseTimeMs: (json['response_time_ms'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
    );
  }

  /// Converts this data model to a domain entity.
  ConversationMessage toEntity() {
    return ConversationMessage(
      id:
          messageId?.toString() ??
          '${sessionId}_${DateTime.now().millisecondsSinceEpoch}',
      speaker: ConversationSpeaker.fromString(speaker),
      sourceText: sourceText,
      translatedText: translatedText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      timestamp: timestamp?.toLocal() ?? DateTime.now(),
      isCached: isCached,
      responseTimeMs: responseTimeMs,
    );
  }
}
