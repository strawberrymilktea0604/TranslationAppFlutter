import 'package:isar_community/isar.dart';

import 'package:frontend/features/history/data/models/history_model.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class HistoryLocalDataSource {
  /// Returns all non-deleted history items, sorted by most recent first.
  /// Optionally filtered by [searchQuery] (matches source or translated text)
  /// and/or [langFilter] (matches "en→vi" format or single lang code).
  Future<List<HistoryModel>> getAll({
    String? searchQuery,
    String? langFilter,
    int offset = 0,
    int limit = 50,
  });

  /// Reactive stream — emits whenever history changes.
  Stream<List<HistoryModel>> watchAll();

  /// Save or update (upsert by backendId).
  Future<void> save(HistoryModel item);

  /// Save a batch of items in a single write transaction.
  Future<void> saveAll(List<HistoryModel> items);

  /// Soft-delete a single item.
  Future<void> softDelete(int isarId);

  /// Soft-delete all items.
  Future<void> clearAll();

  /// Count of non-deleted items.
  Future<int> count();

  /// Get all items that haven't been synced yet (for background upload).
  Future<List<HistoryModel>> getUnsynced();

  /// Mark items as synced after successful upload.
  Future<void> markSynced(List<int> isarIds);
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

class HistoryLocalDataSourceImpl implements HistoryLocalDataSource {
  final Isar _isar;

  const HistoryLocalDataSourceImpl({required Isar isar}) : _isar = isar;

  @override
  Future<List<HistoryModel>> getAll({
    String? searchQuery,
    String? langFilter,
    int offset = 0,
    int limit = 50,
  }) async {
    var query = _isar.historyModels
        .filter()
        .isDeletedEqualTo(false);

    // Apply text search (case-insensitive contains on source or translated)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      query = query.group((g) => g
          .sourceTextContains(q, caseSensitive: false)
          .or()
          .translatedTextContains(q, caseSensitive: false));
    }

    // Apply language filter (e.g. "en" matches sourceLanguage or targetLanguage,
    // or "en→vi" matches exact pair)
    if (langFilter != null && langFilter.trim().isNotEmpty) {
      final parts = langFilter.split('→');
      if (parts.length == 2) {
        query = query
            .sourceLanguageEqualTo(parts[0].trim())
            .targetLanguageEqualTo(parts[1].trim());
      } else {
        final lang = langFilter.trim();
        query = query.group((g) => g
            .sourceLanguageEqualTo(lang)
            .or()
            .targetLanguageEqualTo(lang));
      }
    }

    return query
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  @override
  Stream<List<HistoryModel>> watchAll() {
    return _isar.historyModels
        .filter()
        .isDeletedEqualTo(false)
        .sortByCreatedAtDesc()
        .limit(200)
        .watch(fireImmediately: true);
  }

  @override
  Future<void> save(HistoryModel item) async {
    await _isar.writeTxn(() async {
      await _isar.historyModels.put(item);
    });
  }

  @override
  Future<void> saveAll(List<HistoryModel> items) async {
    await _isar.writeTxn(() async {
      await _isar.historyModels.putAll(items);
    });
  }

  @override
  Future<void> softDelete(int isarId) async {
    await _isar.writeTxn(() async {
      final item = await _isar.historyModels.get(isarId);
      if (item != null) {
        item.isDeleted = true;
        item.isSynced = false; // needs re-sync
        item.updatedAt = DateTime.now();
        await _isar.historyModels.put(item);
      }
    });
  }

  @override
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      final all = await _isar.historyModels
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      for (final item in all) {
        item.isDeleted = true;
        item.isSynced = false;
        item.updatedAt = DateTime.now();
      }
      await _isar.historyModels.putAll(all);
    });
  }

  @override
  Future<int> count() async {
    return _isar.historyModels
        .filter()
        .isDeletedEqualTo(false)
        .count();
  }

  @override
  Future<List<HistoryModel>> getUnsynced() async {
    return _isar.historyModels
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
  }

  @override
  Future<void> markSynced(List<int> isarIds) async {
    await _isar.writeTxn(() async {
      final items = await _isar.historyModels.getAll(isarIds);
      for (final item in items) {
        if (item != null) {
          item.isSynced = true;
          await _isar.historyModels.put(item);
        }
      }
    });
  }
}
