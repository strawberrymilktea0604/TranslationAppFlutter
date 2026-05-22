import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/history/domain/entities/history_entity.dart';

/// Abstract repository for history feature.
/// UC08 — Tra cứu lịch sử (offline-first).
abstract class HistoryRepository {
  /// Gets all translation history (local-first), with optional search & filter.
  Future<Either<Failure, List<HistoryEntity>>> getHistory({
    String? searchQuery,
    String? langFilter,
    int offset = 0,
    int limit = 50,
  });

  /// Saves a history entry to local DB.
  Future<Either<Failure, void>> saveHistory(HistoryEntity entity);

  /// Deletes a history record (soft delete).
  Future<Either<Failure, void>> deleteHistory(int isarId);

  /// Clears all history (soft delete all).
  Future<Either<Failure, void>> clearHistory();

  /// Count of non-deleted history items.
  Future<Either<Failure, int>> count();
}
