import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/vocabulary/domain/entities/vocabulary_entity.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_local_datasource.dart';

/// Abstract repository for vocabulary feature.
/// UC07 — Lưu từ vựng (offline-first).
abstract class VocabularyRepository {
  /// Get all vocabulary, optionally filtered by search and category.
  Future<Either<Failure, List<VocabularyEntity>>> getVocabularyList({
    String? searchQuery,
    String? category,
  });

  /// Get distinct category names.
  Future<Either<Failure, List<String>>> getCategories();

  /// Get category summaries (name, word count, progress %).
  Future<Either<Failure, List<CategorySummary>>> getCategorySummaries();

  /// Get words in a specific category.
  Future<Either<Failure, List<VocabularyEntity>>> getByCategory(String category);

  /// Save a vocabulary entry.
  Future<Either<Failure, VocabularyEntity>> saveVocabulary({
    required String word,
    required String translation,
    required String sourceLanguage,
    required String targetLanguage,
    String category = 'Chưa phân loại',
    int? categoryId,
    int? translationId,
  });

  /// Toggle starred/favorite status.
  Future<Either<Failure, void>> toggleStar(int isarId);

  /// Update mastery level after review.
  Future<Either<Failure, void>> updateMastery(int isarId, int newLevel);

  /// Soft-delete a vocabulary entry by Isar integer ID.
  Future<Either<Failure, void>> deleteVocabulary(int isarId);
}
