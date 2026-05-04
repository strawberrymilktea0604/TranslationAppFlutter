import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/ocr/domain/repositories/ocr_repository.dart';

/// Parameters for [RetranslateOcrTextUseCase].
class RetranslateParams extends Equatable {
  final String text;
  final String sourceLanguage;
  final String targetLanguage;

  const RetranslateParams({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  List<Object?> get props => [text, sourceLanguage, targetLanguage];
}

/// Re-translates previously extracted OCR text after user edits.
class RetranslateOcrTextUseCase extends UseCase<String, RetranslateParams> {
  final OcrRepository _repository;

  RetranslateOcrTextUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(RetranslateParams params) {
    return _repository.retranslateText(
      text: params.text,
      sourceLanguage: params.sourceLanguage,
      targetLanguage: params.targetLanguage,
    );
  }
}
