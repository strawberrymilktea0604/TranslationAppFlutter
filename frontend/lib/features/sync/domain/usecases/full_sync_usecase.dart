import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/sync_push_entity.dart';
import '../repositories/sync_repository.dart';

/// UC09 — Triggers a full push/pull sync cycle.
///
/// Called by [SyncCubit] whenever the device comes online or
/// a manual sync is requested. Delegates to [SyncRepository.fullSync]
/// which handles:
/// 1. Gathering unsynced records from Isar.
/// 2. Pushing them to `POST /api/v1/sync/push`.
/// 3. Pulling server changes via `GET /api/v1/sync/pull`.
/// 4. Upserting pulled items into local Isar.
/// 5. Exponential backoff retries on failure.
class FullSyncUseCase extends UseCase<SyncPushResponseEntity, NoParams> {
  final SyncRepository repository;

  FullSyncUseCase(this.repository);

  @override
  Future<Either<Failure, SyncPushResponseEntity>> call(
    NoParams params,
  ) async {
    return await repository.fullSync();
  }
}
