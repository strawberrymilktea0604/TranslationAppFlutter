import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/history/domain/entities/history_entity.dart';

/// Abstract repository for history feature.
/// UC08 — Tra cứu lịch sử (offline-first).
abstract class HistoryRepository {
  /// Gets all translation history (local-first).
  Future<Either<Failure, List<HistoryEntity>>> getHistory();

  /// Deletes a history record (soft delete).
  Future<Either<Failure, void>> deleteHistory(String id);

  /// Clears all history.
  Future<Either<Failure, void>> clearHistory();
}
