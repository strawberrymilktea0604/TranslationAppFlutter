// Stub implementations for Web platform.
// Isar 3.x does NOT support Flutter Web. These stubs return empty data
// so the admin dashboard can boot without a local offline database.

import 'package:frontend/features/history/data/datasources/history_local_datasource.dart';
import 'package:frontend/features/history/data/models/history_model.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_local_datasource.dart';
import 'package:frontend/features/vocabulary/data/models/question_bank_model.dart';
import 'package:frontend/features/vocabulary/data/models/quiz_result_model.dart';
import 'package:frontend/features/vocabulary/data/models/vocabulary_model.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_category_local_datasource.dart';
import 'package:frontend/features/vocabulary/data/models/vocabulary_category_model.dart';

/// Web stub — all operations are no-ops / return empty collections.
class WebVocabularyLocalDataSource implements VocabularyLocalDataSource {
  const WebVocabularyLocalDataSource();

  @override
  Future<List<VocabularyModel>> getAll({
    String? searchQuery,
    String? category,
    int offset = 0,
    int limit = 100,
  }) async => [];

  @override
  Future<List<String>> getCategories() async => [];

  @override
  Future<List<CategorySummary>> getCategorySummaries() async => [];

  @override
  Future<List<VocabularyModel>> getByCategory(String category) async => [];

  @override
  Stream<List<VocabularyModel>> watchByCategory(String category) =>
      Stream.value([]);

  @override
  Future<void> save(VocabularyModel item) async {}

  @override
  Future<void> saveAll(List<VocabularyModel> items) async {}

  @override
  Future<void> toggleStar(int isarId) async {}

  @override
  Future<void> updateMastery(int isarId, int newLevel) async {}

  @override
  Future<void> softDelete(int isarId) async {}

  @override
  Future<List<VocabularyModel>> getUnsynced() async => [];

  @override
  Future<void> markSynced(List<int> isarIds) async {}

  @override
  Future<void> markSyncedAndUpdateId(Map<int, String> idMap) async {}

  @override
  Future<void> deleteSynced(List<int> isarIds) async {}

  @override
  Future<void> deleteNotPresent(List<String> validBackendIds) async {}

  @override
  Future<List<QuestionBankModel>> getAllBanks() async => [];

  @override
  Future<void> saveBank(QuestionBankModel bank) async {}

  @override
  Future<void> saveAllBanks(List<QuestionBankModel> banks) async {}

  @override
  Future<List<QuizResultModel>> getQuizResults({
    int offset = 0,
    int limit = 50,
  }) async => [];

  @override
  Future<List<QuizResultModel>> getQuizResultsByBank(
      String bankBackendId) async => [];

  @override
  Future<void> saveQuizResult(QuizResultModel result) async {}

  @override
  Future<List<QuizResultModel>> getUnsyncedQuizResults() async => [];

  @override
  Future<void> markQuizResultsSynced(List<int> isarIds) async {}

  @override
  Future<void> markQuizResultsSyncedAndUpdateId(Map<int, String> idMap) async {}
}

/// Web stub for history — returns empty data.
class WebHistoryLocalDataSource implements HistoryLocalDataSource {
  const WebHistoryLocalDataSource();

  @override
  Future<List<HistoryModel>> getAll({
    String? searchQuery,
    String? langFilter,
    int offset = 0,
    int limit = 50,
  }) async => [];

  @override
  Stream<List<HistoryModel>> watchAll() => Stream.value([]);

  @override
  Future<void> save(HistoryModel item) async {}

  @override
  Future<void> saveAll(List<HistoryModel> items) async {}

  @override
  Future<void> softDelete(int isarId) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<int> count() async => 0;

  @override
  Future<List<HistoryModel>> getUnsynced() async => [];

  @override
  Future<void> markSynced(List<int> isarIds) async {}
}

/// Web stub for vocabulary category — returns empty data.
class WebVocabularyCategoryLocalDataSource
    implements VocabularyCategoryLocalDataSource {
  const WebVocabularyCategoryLocalDataSource();

  @override
  Future<List<VocabularyCategoryModel>> getCategories() async => [];

  @override
  Future<VocabularyCategoryModel?> getCategoryById(int backendId) async => null;

  @override
  Future<void> saveCategory(VocabularyCategoryModel category) async {}

  @override
  Future<void> deleteCategory(int backendId) async {}

  @override
  Future<void> saveCategories(
      List<VocabularyCategoryModel> categories) async {}
}
