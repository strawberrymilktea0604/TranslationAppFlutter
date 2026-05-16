import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/data/datasources/auth_local_datasource.dart';
import '../../../vocabulary/data/datasources/vocabulary_local_datasource.dart';
import '../../domain/entities/sync_entity.dart';
import '../../domain/repositories/sync_repository.dart';
import '../datasources/sync_remote_datasource.dart';
import '../models/sync_model.dart';

/// Offline-first sync implementation with Exponential Backoff.
///
/// Flow (§5.2, §5.3):
/// 1. Query Isar for all records where [isSynced] = false.
/// 2. If no unsynced records → return early (nothing to do).
/// 3. Build a batch request and POST to `/api/v1/sync/vocabulary`.
/// 4. On success → mark synced entries as [isSynced] = true in Isar.
/// 5. On 401 → attempt token refresh, then retry.
/// 6. On other failure → retry with Exponential Backoff: 5s, 10s, 30s.
class SyncRepositoryImpl implements SyncRepository {
  final SyncRemoteDataSource _remoteDataSource;
  final VocabularyLocalDataSource _localDataSource;
  final AuthLocalDataSource _authLocalDataSource;

  /// Exponential backoff delays in seconds (§5.3).
  static const List<int> _retryDelays = [5, 10, 30];

  SyncRepositoryImpl({
    required SyncRemoteDataSource remoteDataSource,
    required VocabularyLocalDataSource localDataSource,
    required AuthLocalDataSource authLocalDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _authLocalDataSource = authLocalDataSource;

  @override
  Future<Either<Failure, SyncResponseEntity>> syncVocabulary() async {
    // 1. Gather all unsynced records from Isar.
    final unsyncedModels = await _localDataSource.getUnsyncedEntries();

    if (unsyncedModels.isEmpty) {
      developer.log(
        'No unsynced entries — skipping sync.',
        name: 'SyncRepository',
      );
      return const Right(
        SyncResponseEntity(syncedCount: 0, results: []),
      );
    }

    developer.log(
      'Found ${unsyncedModels.length} unsynced entries. Starting sync…',
      name: 'SyncRepository',
    );

    // 2. Build the batch request.
    final requestItems = unsyncedModels
        .map(SyncVocabularyItemModel.fromVocabularyModel)
        .toList();
    final request = SyncVocabularyRequestModel(items: requestItems);

    // 3. Attempt sync with exponential backoff.
    for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
      try {
        final token = await _authLocalDataSource.getAccessToken();
        if (token == null) {
          return const Left(
            AuthFailure('Not authenticated — sync requires login.'),
          );
        }

        final response = await _remoteDataSource.syncVocabulary(
          request: request,
          accessToken: token,
        );

        // 4. Mark successfully synced items in Isar.
        final syncedIds = <int>[];
        for (final result in response.results) {
          if (result.status == 'created' || result.status == 'updated') {
            // Find the local model by clientId (backendId).
            final localModel = unsyncedModels.where(
              (m) => m.backendId == result.clientId,
            );
            if (localModel.isNotEmpty) {
              syncedIds.add(localModel.first.id);
            }
          }
        }

        if (syncedIds.isNotEmpty) {
          await _localDataSource.markAsSynced(syncedIds);
        }

        developer.log(
          'Sync completed: ${response.syncedCount} items synced.',
          name: 'SyncRepository',
        );

        return Right(response.toEntity());
      } on AuthException {
        // 5. Token expired — stop sync. User must re-authenticate.
        //    Per §5.3: "Nếu Refresh Token cũng thất bại → dừng toàn bộ sync"
        developer.log(
          'Auth expired during sync — stopping.',
          name: 'SyncRepository',
          level: 900,
        );
        return const Left(
          AuthFailure('Session expired. Please log in again to sync.'),
        );
      } on ServerException catch (e) {
        // 6. Server error — retry with backoff.
        if (attempt < _retryDelays.length) {
          final delay = _retryDelays[attempt];
          developer.log(
            'Sync attempt ${attempt + 1} failed: ${e.message}. '
            'Retrying in ${delay}s…',
            name: 'SyncRepository',
            level: 800,
          );
          await Future<void>.delayed(Duration(seconds: delay));
        } else {
          developer.log(
            'Sync failed after ${_retryDelays.length + 1} attempts: '
            '${e.message}',
            name: 'SyncRepository',
            level: 1000,
          );
          return Left(
            ServerFailure(
              'Sync failed after retries: ${e.message}',
              statusCode: e.statusCode,
            ),
          );
        }
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      }
    }

    // Should not reach here, but satisfy the compiler.
    return const Left(ServerFailure('Sync failed unexpectedly.'));
  }
}
