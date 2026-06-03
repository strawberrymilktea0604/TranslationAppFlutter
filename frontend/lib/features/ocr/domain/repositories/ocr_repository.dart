import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/ocr/domain/entities/ocr_entity.dart';
import 'package:frontend/features/translation/domain/entities/translation_entity.dart';

/// Abstract repository for OCR operations (UC06).
///
/// Requires Auth. Requires Network. Max image size: 5 MB (§7.2).
abstract class OcrRepository {
  /// Uploads an image for OCR text extraction + translation.
  ///
  /// [imageBytes] must be ≤ 5 MB after compression.
  /// Calls [onProgress] with values 0.0 → 1.0+ during upload/processing.
  Future<Either<Failure, OcrTranslationEntity>> translateImage({
    required Uint8List imageBytes,
    required String filename,
    required String sourceLanguage,
    required String targetLanguage,
    required void Function(double progress) onProgress,
  });

  /// Re-translates previously extracted OCR text after user edits.
  Future<Either<Failure, TranslationEntity>> retranslateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });
}
