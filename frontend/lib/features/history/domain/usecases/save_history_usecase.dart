import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/history/domain/entities/history_entity.dart';
import 'package:frontend/features/history/domain/repositories/history_repository.dart';

class SaveHistoryUseCase implements UseCase<void, SaveHistoryParams> {
  final HistoryRepository repository;

  SaveHistoryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(SaveHistoryParams params) async {
    return await repository.saveHistory(params.entity);
  }
}

class SaveHistoryParams {
  final HistoryEntity entity;

  SaveHistoryParams({required this.entity});
}
