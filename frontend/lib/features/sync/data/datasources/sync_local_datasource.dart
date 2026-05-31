import 'package:isar_community/isar.dart';

import '../models/sync_cursor_model.dart';

/// Local data source for sync metadata (cursor, timestamps).
///
/// Responsible for persisting the pull cursor so the app knows
/// where to resume pulling server changes after a restart.
abstract class SyncLocalDataSource {
  /// Returns the saved pull cursor, or null if no sync has occurred.
  Future<String?> getSyncCursor();

  /// Persists the pull cursor from the latest successful pull.
  Future<void> saveSyncCursor(String cursor);

  /// Clears the saved cursor (e.g., on logout).
  Future<void> clearSyncCursor();

  /// Returns the timestamp of the last successful pull, or null.
  Future<DateTime?> getLastSyncTimestamp();
}

/// Isar-backed implementation of [SyncLocalDataSource].
class SyncLocalDataSourceImpl implements SyncLocalDataSource {
  final Isar _isar;

  const SyncLocalDataSourceImpl({required Isar isar}) : _isar = isar;

  @override
  Future<String?> getSyncCursor() async {
    final cursor = await _isar.syncCursorModels.get(1);
    return cursor?.cursorValue;
  }

  @override
  Future<void> saveSyncCursor(String cursor) async {
    await _isar.writeTxn(() async {
      final model = SyncCursorModel(
        cursorValue: cursor,
        lastSyncAt: DateTime.now(),
      );
      await _isar.syncCursorModels.put(model);
    });
  }

  @override
  Future<void> clearSyncCursor() async {
    await _isar.writeTxn(() async {
      await _isar.syncCursorModels.delete(1);
    });
  }

  @override
  Future<DateTime?> getLastSyncTimestamp() async {
    final cursor = await _isar.syncCursorModels.get(1);
    return cursor?.lastSyncAt;
  }
}
