import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/ocr/domain/entities/ocr_entity.dart';
import 'package:frontend/features/ocr/domain/repositories/ocr_repository.dart';

/// Parameters for [OcrTranslateUseCase].
class OcrTranslateParams extends Equatable {
  final Uint8List imageBytes;
  final String filename;
  final String sourceLanguage;
  final String targetLanguage;
  final void Function(double progress) onProgress;

  const OcrTranslateParams({
    required this.imageBytes,
    required this.filename,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.onProgress,
  });

  @override
  List<Object?> get props => [filename, sourceLanguage, targetLanguage];
}

/// UC06 — Uploads an image for OCR text extraction + translation.
///
/// Requires authenticated user and network connectivity.
class OcrTranslateUseCase extends UseCase<OcrTranslationEntity, OcrTranslateParams> {
  final OcrRepository _repository;

  OcrTranslateUseCase(this._repository);

  @override
  Future<Either<Failure, OcrTranslationEntity>> call(OcrTranslateParams params) {
    return _repository.translateImage(
      imageBytes: params.imageBytes,
      filename: params.filename,
      sourceLanguage: params.sourceLanguage,
      targetLanguage: params.targetLanguage,
      onProgress: params.onProgress,
    );
  }
}
