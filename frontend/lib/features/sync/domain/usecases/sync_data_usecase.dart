import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/sync_entity.dart';
import '../repositories/sync_repository.dart';

/// UC09 — Triggers a full vocabulary sync cycle.
///
/// Called by [SyncCubit] whenever the device comes online.
/// Delegates to [SyncRepository] which handles:
/// 1. Gathering unsynced records from Isar.
/// 2. Sending them to the backend in a batch.
/// 3. Marking them as synced on success.
/// 4. Exponential backoff retries on failure.
class SyncDataUseCase extends UseCase<SyncResponseEntity, NoParams> {
  final SyncRepository repository;

  SyncDataUseCase(this.repository);

  @override
  Future<Either<Failure, SyncResponseEntity>> call(NoParams params) async {
    return await repository.syncVocabulary();
  }
}
