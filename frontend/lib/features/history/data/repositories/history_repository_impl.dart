import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/history/data/datasources/history_local_datasource.dart';
import 'package:frontend/features/history/data/models/history_model.dart';
import 'package:frontend/features/history/domain/entities/history_entity.dart';
import 'package:frontend/features/history/domain/repositories/history_repository.dart';

/// Offline-first implementation of [HistoryRepository].
///
/// UC08 — Tra cứu lịch sử:
/// - All reads come from local Isar DB.
/// - Writes save locally with [isSynced] = false.
/// - Server sync is handled separately by the Sync feature.
class HistoryRepositoryImpl implements HistoryRepository {
  final HistoryLocalDataSource _localDataSource;

  HistoryRepositoryImpl({required HistoryLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  @override
  Future<Either<Failure, List<HistoryEntity>>> getHistory({
    String? searchQuery,
    String? langFilter,
    int offset = 0,
    int limit = 50,
  }) async {
    try {
      final models = await _localDataSource.getAll(
        searchQuery: searchQuery,
        langFilter: langFilter,
        offset: offset,
        limit: limit,
      );
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } catch (e) {
      return Left(CacheFailure('Failed to load history: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveHistory(HistoryEntity entity) async {
    try {
      final model = HistoryModel.fromEntity(entity);
      await _localDataSource.save(model);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to save history: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteHistory(int isarId) async {
    try {
      await _localDataSource.softDelete(isarId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to delete history item: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearHistory() async {
    try {
      await _localDataSource.clearAll();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to clear history: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> count() async {
    try {
      final c = await _localDataSource.count();
      return Right(c);
    } catch (e) {
      return Left(CacheFailure('Failed to count history: $e'));
    }
  }
}
