import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Pure Dart entity representing the result of an OCR + translation pipeline.
///
/// Belongs to the Domain layer — no framework dependencies.
class OcrTranslationEntity extends Equatable {
  /// Text extracted from the image by the OCR engine.
  final String extractedText;

  /// Translation of the extracted text.
  final String translatedText;

  /// Raw image bytes used for display.
  final Uint8List imageBytes;

  /// Source language code (e.g. 'en', 'auto').
  final String sourceLanguage;

  /// Target language code (e.g. 'vi').
  final String targetLanguage;

  /// OCR confidence score (0–100), if available.
  final double? confidence;

  const OcrTranslationEntity({
    required this.extractedText,
    required this.translatedText,
    required this.imageBytes,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.confidence,
  });

  @override
  List<Object?> get props => [
        extractedText,
        translatedText,
        sourceLanguage,
        targetLanguage,
        confidence,
      ];
}
