import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/vocabulary_entity.dart';
import '../repositories/vocabulary_repository.dart';

/// UC08 — Retrieves saved vocabulary list from local Isar DB.
/// Offline-first: always reads from local storage.
class GetVocabularyListUseCase
    extends UseCase<List<VocabularyEntity>, NoParams> {
  final VocabularyRepository repository;

  GetVocabularyListUseCase(this.repository);

  @override
  Future<Either<Failure, List<VocabularyEntity>>> call(
    NoParams params,
  ) async {
    return await repository.getVocabularyList();
  }
}
