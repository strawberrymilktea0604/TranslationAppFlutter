import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/sync/domain/entities/sync_entity.dart';

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
}
