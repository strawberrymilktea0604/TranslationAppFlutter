import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/vocabulary_entity.dart';
import '../repositories/vocabulary_repository.dart';

/// UC07 — Saves a vocabulary entry to local Isar DB.
/// The entry is saved with [isSynced] = false for later sync.
class SaveVocabularyUseCase
    extends UseCase<VocabularyEntity, SaveVocabularyParams> {
  final VocabularyRepository repository;

  SaveVocabularyUseCase(this.repository);

  @override
  Future<Either<Failure, VocabularyEntity>> call(
    SaveVocabularyParams params,
  ) async {
    return await repository.saveVocabulary(
      word: params.word,
      translation: params.translation,
      sourceLanguage: params.sourceLanguage,
      targetLanguage: params.targetLanguage,
      category: params.category,
      translationId: params.translationId,
    );
  }
}

/// Parameters for [SaveVocabularyUseCase].
class SaveVocabularyParams extends Equatable {
  final String word;
  final String translation;
  final String sourceLanguage;
  final String targetLanguage;
  final String category;
  final int? translationId;

  const SaveVocabularyParams({
    required this.word,
    required this.translation,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.category = 'Chưa phân loại',
    this.translationId,
  });

  @override
  List<Object?> get props => [
        word,
        translation,
        sourceLanguage,
        targetLanguage,
        category,
        translationId,
      ];
}
