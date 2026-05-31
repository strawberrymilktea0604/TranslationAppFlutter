import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/sync/domain/entities/sync_entity.dart';
import 'package:frontend/features/sync/domain/entities/sync_push_entity.dart';

/// Abstract repository for UC09 — Đồng bộ dữ liệu.
///
/// Implementations must follow:
/// - Last-Write-Wins strategy based on updated_at (§5.2).
/// - Exponential Backoff retry: 5s, 10s, 30s (§5.3).
/// - Token refresh before retry if 401 (§5.3).
abstract class SyncRepository {
  /// Gathers all unsynced vocabulary records from local Isar DB,
  /// sends them to the backend sync API, and marks them as synced
  /// upon success.
  ///
  /// Returns [SyncResponseEntity] on success or [Failure] on error.
  Future<Either<Failure, SyncResponseEntity>> syncVocabulary();

  /// Performs a full sync cycle using the modern push/pull protocol:
  ///
  /// 1. Gather all unsynced local records (vocabulary).
  /// 2. Push them via `POST /api/v1/sync/push`.
  /// 3. Process push results (mark synced, update backendId).
  /// 4. Pull server changes via `GET /api/v1/sync/pull` (cursor-based).
  /// 5. Upsert pulled items into local Isar DB.
  /// 6. Persist the new cursor for next sync.
  ///
  /// Returns [SyncPushResponseEntity] summarizing the push results,
  /// or [Failure] on error.
  Future<Either<Failure, SyncPushResponseEntity>> fullSync();
}
