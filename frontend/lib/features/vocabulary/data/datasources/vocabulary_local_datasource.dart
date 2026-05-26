import 'package:isar_community/isar.dart';

import 'package:frontend/features/vocabulary/data/models/vocabulary_model.dart';
import 'package:frontend/features/vocabulary/data/models/question_bank_model.dart';
import 'package:frontend/features/vocabulary/data/models/quiz_result_model.dart';
import 'package:frontend/features/vocabulary/data/models/vocabulary_category_model.dart';

// ---------------------------------------------------------------------------
// Category summary DTO
// ---------------------------------------------------------------------------

class CategorySummary {
  final String name;
  final int wordCount;

  /// How many words have masteryLevel >= 3 (considered "learned").
  final int learnedCount;

  /// Progress percentage (0.0 – 100.0).
  double get progress =>
      wordCount == 0 ? 0.0 : (learnedCount / wordCount * 100);

  const CategorySummary({
    required this.name,
    required this.wordCount,
    required this.learnedCount,
  });
}

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class VocabularyLocalDataSource {
  // ---- Vocabulary CRUD ----

  /// All non-deleted words, optionally filtered.
  Future<List<VocabularyModel>> getAll({
    String? searchQuery,
    String? category,
    int offset = 0,
    int limit = 100,
  });

  /// Distinct category names for non-deleted words.
  Future<List<String>> getCategories();

  /// Summary per category (name, count, progress %).
  Future<List<CategorySummary>> getCategorySummaries();

  /// Words in a specific category.
  Future<List<VocabularyModel>> getByCategory(String category);

  /// Reactive stream for a specific category.
  Stream<List<VocabularyModel>> watchByCategory(String category);

  /// Save or update (upsert by backendId).
  Future<void> save(VocabularyModel item);

  /// Save a batch.
  Future<void> saveAll(List<VocabularyModel> items);

  /// Toggle the starred/favorite flag.
  Future<void> toggleStar(int isarId);

  /// Update mastery level after a review session.
  Future<void> updateMastery(int isarId, int newLevel);

  /// Soft-delete.
  Future<void> softDelete(int isarId);

  /// Get unsynced items for background upload.
  Future<List<VocabularyModel>> getUnsynced();

  /// Mark items as synced.
  Future<void> markSynced(List<int> isarIds);

  /// Mark items as synced and update their backendId.
  Future<void> markSyncedAndUpdateId(Map<int, String> idMap);

  /// Delete items after sync.
  Future<void> deleteSynced(List<int> isarIds);

  /// Deletes all vocabularies not present in the valid backend ID list.
  Future<void> deleteNotPresent(List<String> validBackendIds);

  // ---- Question Bank ----

  /// All non-deleted question banks.
  Future<List<QuestionBankModel>> getAllBanks();

  /// Save/update a question bank.
  Future<void> saveBank(QuestionBankModel bank);

  /// Save multiple banks.
  Future<void> saveAllBanks(List<QuestionBankModel> banks);

  // ---- Quiz Results ----

  /// All quiz results sorted by most recent.
  Future<List<QuizResultModel>> getQuizResults({int offset = 0, int limit = 50});

  /// Quiz results for a specific bank.
  Future<List<QuizResultModel>> getQuizResultsByBank(String bankBackendId);

  /// Save a quiz result.
  Future<void> saveQuizResult(QuizResultModel result);

  /// Get unsynced quiz results for background upload.
  Future<List<QuizResultModel>> getUnsyncedQuizResults();

  /// Mark quiz results as synced.
  Future<void> markQuizResultsSynced(List<int> isarIds);
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

class VocabularyLocalDataSourceImpl implements VocabularyLocalDataSource {
  final Isar _isar;

  const VocabularyLocalDataSourceImpl({required Isar isar}) : _isar = isar;

  // =========================================================================
  // Vocabulary CRUD
  // =========================================================================

  @override
  Future<List<VocabularyModel>> getAll({
    String? searchQuery,
    String? category,
    int offset = 0,
    int limit = 100,
  }) async {
    var query = _isar.vocabularyModels
        .filter()
        .isDeletedEqualTo(false);

    if (category != null && category.isNotEmpty) {
      query = query.categoryEqualTo(category);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      query = query.group((g) => g
          .wordContains(q, caseSensitive: false)
          .or()
          .translationContains(q, caseSensitive: false));
    }

    return query
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  @override
  Future<List<String>> getCategories() async {
    final all = await _isar.vocabularyModels
        .filter()
        .isDeletedEqualTo(false)
        .distinctByCategory()
        .findAll();
    return all.map((m) => m.category).toSet().toList()..sort();
  }

  @override
  Future<List<CategorySummary>> getCategorySummaries() async {
    final categories = await _isar.vocabularyCategoryModels.filter().isDeletedEqualTo(false).findAll();
    final summaries = <CategorySummary>[];

    for (final cat in categories) {
      final words = await _isar.vocabularyModels
          .filter()
          .isDeletedEqualTo(false)
          .categoryIdEqualTo(cat.backendId) // Query by ID
          .findAll();

      final learned = words.where((w) => w.masteryLevel >= 3).length;

      summaries.add(CategorySummary(
        name: cat.name,
        wordCount: words.length,
        learnedCount: learned,
      ));
    }

    // Include "Chưa phân loại" for words without category
    final uncategorizedWords = await _isar.vocabularyModels
          .filter()
          .isDeletedEqualTo(false)
          .categoryIdIsNull()
          .findAll();

    if (uncategorizedWords.isNotEmpty) {
      final learned = uncategorizedWords.where((w) => w.masteryLevel >= 3).length;
      summaries.add(CategorySummary(
        name: 'Chưa phân loại',
        wordCount: uncategorizedWords.length,
        learnedCount: learned,
      ));
    }

    return summaries;
  }

  @override
  Future<List<VocabularyModel>> getByCategory(String category) async {
    return _isar.vocabularyModels
        .filter()
        .isDeletedEqualTo(false)
        .categoryEqualTo(category)
        .sortByCreatedAtDesc()
        .findAll();
  }

  @override
  Stream<List<VocabularyModel>> watchByCategory(String category) {
    return _isar.vocabularyModels
        .filter()
        .isDeletedEqualTo(false)
        .categoryEqualTo(category)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  @override
  Future<void> save(VocabularyModel item) async {
    await _isar.writeTxn(() async {
      await _isar.vocabularyModels.put(item);
    });
  }

  @override
  Future<void> saveAll(List<VocabularyModel> items) async {
    await _isar.writeTxn(() async {
      await _isar.vocabularyModels.putAll(items);
    });
  }

  @override
  Future<void> toggleStar(int isarId) async {
    await _isar.writeTxn(() async {
      final item = await _isar.vocabularyModels.get(isarId);
      if (item != null) {
        item.isStarred = !item.isStarred;
        item.isSynced = false;
        item.updatedAt = DateTime.now();
        await _isar.vocabularyModels.put(item);
      }
    });
  }

  @override
  Future<void> updateMastery(int isarId, int newLevel) async {
    await _isar.writeTxn(() async {
      final item = await _isar.vocabularyModels.get(isarId);
      if (item != null) {
        item.masteryLevel = newLevel.clamp(0, 5);
        item.lastTestedAt = DateTime.now();
        item.isSynced = false;
        item.updatedAt = DateTime.now();
        await _isar.vocabularyModels.put(item);
      }
    });
  }

  @override
  Future<void> softDelete(int isarId) async {
    await _isar.writeTxn(() async {
      final item = await _isar.vocabularyModels.get(isarId);
      if (item != null) {
        item.isDeleted = true;
        item.isSynced = false;
        item.updatedAt = DateTime.now();
        await _isar.vocabularyModels.put(item);
      }
    });
  }

  @override
  Future<List<VocabularyModel>> getUnsynced() async {
    return _isar.vocabularyModels
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
  }

  @override
  Future<void> markSynced(List<int> isarIds) async {
    await _isar.writeTxn(() async {
      final items = await _isar.vocabularyModels.getAll(isarIds);
      for (final item in items) {
        if (item != null) {
          item.isSynced = true;
          await _isar.vocabularyModels.put(item);
        }
      }
    });
  }

  @override
  Future<void> markSyncedAndUpdateId(Map<int, String> idMap) async {
    await _isar.writeTxn(() async {
      final ids = idMap.keys.toList();
      final items = await _isar.vocabularyModels.getAll(ids);
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        if (item != null) {
          item.isSynced = true;
          item.backendId = idMap[ids[i]]!;
          await _isar.vocabularyModels.put(item);
        }
      }
    });
  }

  @override
  Future<void> deleteSynced(List<int> isarIds) async {
    await _isar.writeTxn(() async {
      await _isar.vocabularyModels.deleteAll(isarIds);
    });
  }

  @override
  Future<void> deleteNotPresent(List<String> validBackendIds) async {
    await _isar.writeTxn(() async {
      final List<int> idsToDelete;
      if (validBackendIds.isEmpty) {
        // If server has no records, delete all synced records.
        // We only delete synced ones so we don't accidentally wipe offline records
        // that haven't been pushed yet (though they should have been pushed earlier).
        final toDelete = await _isar.vocabularyModels.filter().isSyncedEqualTo(true).findAll();
        idsToDelete = toDelete.map((e) => e.id).toList();
      } else {
        final toDelete = await _isar.vocabularyModels
            .filter()
            .not()
            .anyOf(validBackendIds, (q, String id) => q.backendIdEqualTo(id))
            .findAll();
        idsToDelete = toDelete.map((e) => e.id).toList();
      }
      await _isar.vocabularyModels.deleteAll(idsToDelete);
    });
  }

  // =========================================================================
  // Question Banks
  // =========================================================================

  @override
  Future<List<QuestionBankModel>> getAllBanks() async {
    return _isar.questionBankModels
        .filter()
        .isDeletedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  @override
  Future<void> saveBank(QuestionBankModel bank) async {
    await _isar.writeTxn(() async {
      await _isar.questionBankModels.put(bank);
    });
  }

  @override
  Future<void> saveAllBanks(List<QuestionBankModel> banks) async {
    await _isar.writeTxn(() async {
      await _isar.questionBankModels.putAll(banks);
    });
  }

  // =========================================================================
  // Quiz Results
  // =========================================================================

  @override
  Future<List<QuizResultModel>> getQuizResults({
    int offset = 0,
    int limit = 50,
  }) async {
    return _isar.quizResultModels
        .where()
        .sortByCompletedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  @override
  Future<List<QuizResultModel>> getQuizResultsByBank(
      String bankBackendId) async {
    return _isar.quizResultModels
        .filter()
        .bankBackendIdEqualTo(bankBackendId)
        .sortByCompletedAtDesc()
        .findAll();
  }

  @override
  Future<void> saveQuizResult(QuizResultModel result) async {
    await _isar.writeTxn(() async {
      await _isar.quizResultModels.put(result);
    });
  }

  @override
  Future<List<QuizResultModel>> getUnsyncedQuizResults() async {
    return _isar.quizResultModels
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
  }

  @override
  Future<void> markQuizResultsSynced(List<int> isarIds) async {
    await _isar.writeTxn(() async {
      final items = await _isar.quizResultModels.getAll(isarIds);
      for (final item in items) {
        if (item != null) {
          item.isSynced = true;
          await _isar.quizResultModels.put(item);
        }
      }
    });
  }
}
