import 'package:isar_community/isar.dart';

part 'sync_cursor_model.g.dart';

/// Isar collection for persisting the sync cursor.
///
/// The cursor is an opaque string returned by `GET /api/v1/sync/pull`.
/// It encodes the last pull position so subsequent pulls only receive
/// changes since the last sync.
///
/// Only one record exists in this collection at any time (id = 1).
@collection
class SyncCursorModel {
  /// Fixed ID = 1 so we always overwrite the same record.
  Id id = 1;

  /// The opaque cursor string from the pull response.
  late String cursorValue;

  /// When this cursor was last updated (i.e., last successful pull).
  late DateTime lastSyncAt;

  SyncCursorModel({
    required this.cursorValue,
    required this.lastSyncAt,
  });

  SyncCursorModel.isar();
}
