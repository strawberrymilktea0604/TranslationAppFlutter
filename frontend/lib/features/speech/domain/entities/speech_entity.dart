import 'package:equatable/equatable.dart';

/// Pure Dart entity representing a voice translation result.
///
/// Contains the STT-extracted text, its translation, and metadata
/// about the STT quality (language probability).
/// No framework dependency — belongs to the Domain layer.
class SpeechTranslationEntity extends Equatable {
  /// Text extracted from audio via Speech-to-Text.
  final String sourceText;

  /// Translated text in the target language.
  final String translatedText;

  /// Detected or specified source language code.
  final String sourceLanguage;

  /// Target language code for translation.
  final String targetLanguage;

  /// STT engine's confidence in the detected language (0.0–1.0).
  final double sttLanguageProbability;

  /// Whether the translation result came from cache.
  final bool isCached;

  /// Total server-side processing time in milliseconds.
  final double responseTimeMs;

  const SpeechTranslationEntity({
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sttLanguageProbability,
    this.isCached = false,
    this.responseTimeMs = 0.0,
  });

  @override
  List<Object?> get props => [
        sourceText,
        translatedText,
        sourceLanguage,
        targetLanguage,
        sttLanguageProbability,
        isCached,
        responseTimeMs,
      ];
}
