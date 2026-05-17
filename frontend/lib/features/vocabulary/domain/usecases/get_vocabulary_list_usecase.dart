import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/vocabulary_entity.dart';
import '../repositories/vocabulary_repository.dart';
import '../../data/datasources/vocabulary_local_datasource.dart';

/// UC07 — Retrieves saved vocabulary list from local Isar DB.
/// Supports optional search query and category filter.
class GetVocabularyListUseCase
    extends UseCase<List<VocabularyEntity>, GetVocabularyListParams> {
  final VocabularyRepository repository;

  GetVocabularyListUseCase(this.repository);

  @override
  Future<Either<Failure, List<VocabularyEntity>>> call(
    GetVocabularyListParams params,
  ) async {
    return await repository.getVocabularyList(
      searchQuery: params.searchQuery,
      category: params.category,
    );
  }
}

/// Parameters for [GetVocabularyListUseCase].
class GetVocabularyListParams {
  final String? searchQuery;
  final String? category;

  const GetVocabularyListParams({this.searchQuery, this.category});
}

/// Retrieves category summaries (name, count, progress %).
class GetCategorySummariesUseCase
    extends UseCase<List<CategorySummary>, NoParams> {
  final VocabularyRepository repository;

  GetCategorySummariesUseCase(this.repository);

  @override
  Future<Either<Failure, List<CategorySummary>>> call(NoParams params) async {
    return await repository.getCategorySummaries();
  }
}
