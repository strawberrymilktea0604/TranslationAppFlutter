import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/vocabulary/domain/entities/vocabulary_entity.dart';
import 'package:frontend/features/vocabulary/domain/repositories/vocabulary_repository.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_local_datasource.dart';
import 'package:frontend/features/vocabulary/data/models/vocabulary_model.dart';

/// Offline-first implementation of [VocabularyRepository].
///
/// UC07 — Lưu từ vựng:
/// - Save always goes to Isar (local) first with [isSynced] = false.
/// - Read always returns data from Isar (local).
/// - Syncing to server is handled by the Sync feature separately.
class VocabularyRepositoryImpl implements VocabularyRepository {
  final VocabularyLocalDataSource _localDataSource;

  VocabularyRepositoryImpl({
    required VocabularyLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  @override
  Future<Either<Failure, List<VocabularyEntity>>> getVocabularyList({
    String? searchQuery,
    String? category,
  }) async {
    try {
      final models = await _localDataSource.getAll(
        searchQuery: searchQuery,
        category: category,
      );
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } catch (e) {
      return Left(CacheFailure('Failed to load vocabulary: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getCategories() async {
    try {
      final categories = await _localDataSource.getCategories();
      return Right(categories);
    } catch (e) {
      return Left(CacheFailure('Failed to load categories: $e'));
    }
  }

  @override
  Future<Either<Failure, List<CategorySummary>>> getCategorySummaries() async {
    try {
      final summaries = await _localDataSource.getCategorySummaries();
      return Right(summaries);
    } catch (e) {
      return Left(CacheFailure('Failed to load category summaries: $e'));
    }
  }

  @override
  Future<Either<Failure, List<VocabularyEntity>>> getByCategory(
      String category) async {
    try {
      final models = await _localDataSource.getByCategory(category);
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } catch (e) {
      return Left(CacheFailure('Failed to load words for category: $e'));
    }
  }

  @override
  Future<Either<Failure, VocabularyEntity>> saveVocabulary({
    required String word,
    required String translation,
    required String sourceLanguage,
    required String targetLanguage,
    String category = 'Chưa phân loại',
    int? categoryId,
    int? translationId,
  }) async {
    try {
      final now = DateTime.now();
      final model = VocabularyModel(
        // Generate a temporary local ID; the server will assign
        // the real UUID upon sync.
        backendId: 'local_${now.millisecondsSinceEpoch}',
        word: word,
        translation: translation,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        category: category,
        categoryId: categoryId,
        translationId: translationId,
        createdAt: now,
        updatedAt: now,
        isSynced: false,
        isDeleted: false,
      );

      await _localDataSource.save(model);
      return Right(model.toEntity());
    } catch (e) {
      return Left(CacheFailure('Failed to save vocabulary: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> toggleStar(int isarId) async {
    try {
      await _localDataSource.toggleStar(isarId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to toggle star: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateMastery(int isarId, int newLevel) async {
    try {
      await _localDataSource.updateMastery(isarId, newLevel);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to update mastery: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteVocabulary(int isarId) async {
    try {
      await _localDataSource.softDelete(isarId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to delete vocabulary: $e'));
    }
  }
}
