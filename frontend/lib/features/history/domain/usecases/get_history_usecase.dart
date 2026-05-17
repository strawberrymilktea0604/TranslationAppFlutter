import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/history/domain/entities/history_entity.dart';
import 'package:frontend/features/history/domain/repositories/history_repository.dart';

/// UC08 — Retrieves translation history from local Isar DB.
/// Supports search query and language pair filter.
class GetHistoryUseCase
    extends UseCase<List<HistoryEntity>, GetHistoryParams> {
  final HistoryRepository repository;

  GetHistoryUseCase(this.repository);

  @override
  Future<Either<Failure, List<HistoryEntity>>> call(
    GetHistoryParams params,
  ) async {
    return await repository.getHistory(
      searchQuery: params.searchQuery,
      langFilter: params.langFilter,
      offset: params.offset,
      limit: params.limit,
    );
  }
}

/// Parameters for [GetHistoryUseCase].
class GetHistoryParams extends Equatable {
  final String? searchQuery;
  final String? langFilter;
  final int offset;
  final int limit;

  const GetHistoryParams({
    this.searchQuery,
    this.langFilter,
    this.offset = 0,
    this.limit = 50,
  });

  @override
  List<Object?> get props => [searchQuery, langFilter, offset, limit];
}

/// Soft-deletes a single history entry.
class DeleteHistoryUseCase extends UseCase<void, DeleteHistoryParams> {
  final HistoryRepository repository;

  DeleteHistoryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteHistoryParams params) async {
    return await repository.deleteHistory(params.isarId);
  }
}

class DeleteHistoryParams extends Equatable {
  final int isarId;
  const DeleteHistoryParams({required this.isarId});

  @override
  List<Object?> get props => [isarId];
}

/// Soft-deletes all history entries.
class ClearHistoryUseCase extends UseCase<void, NoParams> {
  final HistoryRepository repository;

  ClearHistoryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.clearHistory();
  }
}
