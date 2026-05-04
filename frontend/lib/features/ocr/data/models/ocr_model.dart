/// Data Transfer Object for OCR results from the remote API.
///
/// Handles JSON serialization and conversion to the domain entity.
class OcrModel {
  final String extractedText;
  final String translatedText;
  final double? confidence;

  const OcrModel({
    required this.extractedText,
    required this.translatedText,
    this.confidence,
  });

  /// Creates an [OcrModel] from a JSON map returned by the API.
  factory OcrModel.fromJson(Map<String, dynamic> json) {
    return OcrModel(
      extractedText: (json['source_text'] as String?) ?? '',
      translatedText: (json['translated_text'] as String?) ?? '',
      confidence: (json['ocr_confidence'] as num?)?.toDouble(),
    );
  }

  /// Converts to a JSON map.
  Map<String, dynamic> toJson() => {
        'source_text': extractedText,
        'translated_text': translatedText,
        'ocr_confidence': confidence,
      };
}
