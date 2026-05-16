import 'package:isar/isar.dart';

import '../../../../core/error/exceptions.dart';
import '../models/vocabulary_model.dart';

/// Abstract interface for local vocabulary data operations.
/// All methods operate on Isar DB directly.
abstract class VocabularyLocalDataSource {
  /// Saves a vocabulary entry to Isar DB with [isSynced] = false.
  /// Returns the saved [VocabularyModel] with its assigned Isar [Id].
  Future<VocabularyModel> saveVocabulary(VocabularyModel model);

  /// Returns all vocabulary entries that are not soft-deleted,
  /// ordered by [createdAt] descending (newest first).
  Future<List<VocabularyModel>> getVocabularyList();

  /// Soft-deletes a vocabulary entry by setting
  /// [isDeleted] = true and [isSynced] = false.
  Future<void> deleteVocabulary(int isarId);

  /// Returns all entries where [isSynced] = false,
  /// used by the sync feature to push pending changes.
  Future<List<VocabularyModel>> getUnsyncedEntries();

  /// Marks one or more entries as synced after successful
  /// server confirmation. Updates [isSynced] = true.
  Future<void> markAsSynced(List<int> isarIds);
}

/// Isar-backed implementation of [VocabularyLocalDataSource].
class VocabularyLocalDataSourceImpl implements VocabularyLocalDataSource {
  final Isar _isar;

  VocabularyLocalDataSourceImpl({required Isar isar}) : _isar = isar;

  @override
  Future<VocabularyModel> saveVocabulary(VocabularyModel model) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.vocabularyModels.put(model);
      });
      return model;
    } catch (e) {
      throw CacheException(
        message: 'Failed to save vocabulary to local DB: $e',
      );
    }
  }

  @override
  Future<List<VocabularyModel>> getVocabularyList() async {
    try {
      return await _isar.vocabularyModels
          .filter()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .findAll();
    } catch (e) {
      throw CacheException(
        message: 'Failed to load vocabulary from local DB: $e',
      );
    }
  }

  @override
  Future<void> deleteVocabulary(int isarId) async {
    try {
      await _isar.writeTxn(() async {
        final entry = await _isar.vocabularyModels.get(isarId);
        if (entry == null) {
          throw CacheException(
            message: 'Vocabulary entry not found (id=$isarId)',
          );
        }
        // Soft delete: mark as deleted, mark as unsynced
        // so the sync service pushes the deletion to the server.
        entry.isDeleted = true;
        entry.isSynced = false;
        entry.updatedAt = DateTime.now();
        await _isar.vocabularyModels.put(entry);
      });
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException(
        message: 'Failed to delete vocabulary from local DB: $e',
      );
    }
  }

  @override
  Future<List<VocabularyModel>> getUnsyncedEntries() async {
    try {
      return await _isar.vocabularyModels
          .filter()
          .isSyncedEqualTo(false)
          .findAll();
    } catch (e) {
      throw CacheException(
        message: 'Failed to query unsynced entries: $e',
      );
    }
  }

  @override
  Future<void> markAsSynced(List<int> isarIds) async {
    try {
      await _isar.writeTxn(() async {
        for (final id in isarIds) {
          final entry = await _isar.vocabularyModels.get(id);
          if (entry != null) {
            entry.isSynced = true;
            await _isar.vocabularyModels.put(entry);
          }
        }
      });
    } catch (e) {
      throw CacheException(
        message: 'Failed to mark entries as synced: $e',
      );
    }
  }
}
