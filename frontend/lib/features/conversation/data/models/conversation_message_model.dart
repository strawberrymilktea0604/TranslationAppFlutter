import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';

/// Data model for parsing `translation_result` events from the
/// conversation WebSocket.
///
/// Maps raw JSON → [ConversationMessage] entity.
/// Data layer only — the Presentation layer works exclusively with entities.
class ConversationMessageModel {
  final String sessionId;
  final String sourceText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final String? speaker;
  final bool isCached;
  final double responseTimeMs;

  const ConversationMessageModel({
    required this.sessionId,
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.speaker,
    this.isCached = false,
    this.responseTimeMs = 0.0,
  });

  /// Creates a model from the raw JSON map received via WebSocket.
  ///
  /// Expected JSON shape (from backend `translation_result` event):
  /// ```json
  /// {
  ///   "event": "translation_result",
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
      sourceText: json['source_text'] as String? ?? '',
      translatedText: json['translated_text'] as String? ?? '',
      sourceLanguage: json['source_language'] as String? ?? '',
      targetLanguage: json['target_language'] as String? ?? '',
      speaker: json['speaker'] as String?,
      isCached: json['is_cached'] as bool? ?? false,
      responseTimeMs:
          (json['response_time_ms'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this data model to a domain entity.
  ConversationMessage toEntity() {
    return ConversationMessage(
      id: '${sessionId}_${DateTime.now().millisecondsSinceEpoch}',
      speaker: ConversationSpeaker.fromString(speaker),
      sourceText: sourceText,
      translatedText: translatedText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      timestamp: DateTime.now(),
      isCached: isCached,
      responseTimeMs: responseTimeMs,
    );
  }
}
