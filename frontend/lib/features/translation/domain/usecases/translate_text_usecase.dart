import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/translation/domain/entities/translation_entity.dart';
import 'package:frontend/features/translation/domain/repositories/translation_repository.dart';

/// UC01 — Dịch văn bản thuần (Translate plain text).
/// One use case = one file, extends `UseCase<T, P>`.
class TranslateTextUseCase
    extends UseCase<TranslationEntity, TranslateTextParams> {
  final TranslationRepository repository;

  TranslateTextUseCase(this.repository);

  @override
  Future<Either<Failure, TranslationEntity>> call(
    TranslateTextParams params,
  ) async {
    return await repository.translateText(
      text: params.text,
      sourceLanguage: params.sourceLanguage,
      targetLanguage: params.targetLanguage,
    );
  }
}

/// Parameters for [TranslateTextUseCase].
class TranslateTextParams extends Equatable {
  final String text;
  final String sourceLanguage;
  final String targetLanguage;

  const TranslateTextParams({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  List<Object?> get props => [text, sourceLanguage, targetLanguage];
}
