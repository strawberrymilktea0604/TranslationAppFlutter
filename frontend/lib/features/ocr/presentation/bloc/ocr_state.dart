part of 'ocr_cubit.dart';

sealed class OcrState {}

/// No image selected — initial/empty state.
final class OcrInitial extends OcrState {}

/// Image is being uploaded or processed on server.
final class OcrUploading extends OcrState {
  /// 0.0 → 0.9 while uploading bytes; 1.0 when server is running OCR.
  final double progress;
  final String message;
  OcrUploading({required this.progress, required this.message});
}

/// User has edited the OCR text and a re-translation is in progress.
final class OcrRetranslating extends OcrState {
  final String editedText;
  final Uint8List imageBytes;
  final String sourceLang;
  final String targetLang;

  OcrRetranslating({
    required this.editedText,
    required this.imageBytes,
    required this.sourceLang,
    required this.targetLang,
  });
}

/// OCR + translation succeeded.
final class OcrSuccess extends OcrState {
  final String extractedText;
  final String translatedText;
  final Uint8List imageBytes;
  final String sourceLang;
  final String targetLang;
  final double? confidence;

  OcrSuccess({
    required this.extractedText,
    required this.translatedText,
    required this.imageBytes,
    required this.sourceLang,
    required this.targetLang,
    this.confidence,
  });

  OcrSuccess copyWith({
    String? extractedText,
    String? translatedText,
    Uint8List? imageBytes,
    String? sourceLang,
    String? targetLang,
    double? confidence,
  }) =>
      OcrSuccess(
        extractedText: extractedText ?? this.extractedText,
        translatedText: translatedText ?? this.translatedText,
        imageBytes: imageBytes ?? this.imageBytes,
        sourceLang: sourceLang ?? this.sourceLang,
        targetLang: targetLang ?? this.targetLang,
        confidence: confidence ?? this.confidence,
      );
}

/// Pipeline failed at any stage.
final class OcrFailure extends OcrState {
  final String message;
  OcrFailure(this.message);
}
