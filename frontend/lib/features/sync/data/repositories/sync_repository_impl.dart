import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/data/datasources/auth_local_datasource.dart';
import '../../../vocabulary/data/datasources/vocabulary_local_datasource.dart';
import '../../../vocabulary/data/datasources/vocabulary_remote_datasource.dart';
import '../../../vocabulary/data/models/vocabulary_model.dart';
import '../../../vocabulary/data/models/quiz_result_model.dart';
import '../../domain/entities/sync_entity.dart';
import '../../domain/entities/sync_push_entity.dart';
import '../../domain/repositories/sync_repository.dart';
import '../datasources/sync_local_datasource.dart';
import '../datasources/sync_remote_datasource.dart';
import '../models/sync_model.dart';
import '../models/sync_push_model.dart';

/// Offline-first sync implementation with Exponential Backoff.
///
/// Supports two sync modes:
/// 1. **Legacy** [syncVocabulary]: uses `POST /api/v1/sync/vocabulary`.
/// 2. **Modern** [fullSync]: uses `POST /api/v1/sync/push` +
///    `GET /api/v1/sync/pull` with cursor-based pagination.
///
/// Retry behaviour (§5.3):
/// - Exponential Backoff: 5s → 10s → 30s.
/// - Token expired → stop sync (user must re-authenticate).
class SyncRepositoryImpl implements SyncRepository {
  final SyncRemoteDataSource _remoteDataSource;
  final VocabularyLocalDataSource _localDataSource;
  final VocabularyRemoteDataSource _vocabularyRemoteDataSource;
  final AuthLocalDataSource _authLocalDataSource;
  final SyncLocalDataSource _syncLocalDataSource;

  /// Exponential backoff delays in seconds (§5.3).
  static const List<int> _retryDelays = [5, 10, 30];

  SyncRepositoryImpl({
    required SyncRemoteDataSource remoteDataSource,
    required VocabularyLocalDataSource localDataSource,
    required VocabularyRemoteDataSource vocabularyRemoteDataSource,
    required AuthLocalDataSource authLocalDataSource,
    required SyncLocalDataSource syncLocalDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _vocabularyRemoteDataSource = vocabularyRemoteDataSource,
        _authLocalDataSource = authLocalDataSource,
        _syncLocalDataSource = syncLocalDataSource;

  // ==================================================================
  //  Legacy sync (POST /api/v1/sync/vocabulary)
  // ==================================================================

  @override
  Future<Either<Failure, SyncResponseEntity>> syncVocabulary() async {
    // 1. Gather all unsynced records from Isar.
    final unsyncedModels = await _localDataSource.getUnsynced();

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

        // 4. Mark successfully synced items in Isar and update their backendId.
        final idMap = <int, String>{};
        for (final result in response.results) {
          if (result.status == 'created' || result.status == 'updated') {
            final localModel = unsyncedModels.where(
              (m) => m.backendId == result.clientId,
            );
            if (localModel.isNotEmpty) {
              idMap[localModel.first.id] = result.serverId.toString();
            }
          }
        }

        if (idMap.isNotEmpty) {
          await _localDataSource.markSyncedAndUpdateId(idMap);
        }

        // --- PULL SYNC: Overwrite local data with server data ---
        int page = 1;
        bool hasNext = true;
        final serverVocabs = <VocabularyModel>[];
        final serverIds = <String>{};

        while (hasNext) {
          final pageData =
              await _vocabularyRemoteDataSource.getVocabularyList(
            page: page,
            accessToken: token,
          );

          final items = pageData['items'] as List;
          for (final item in items) {
            final jsonMap = item as Map<String, dynamic>;
            final backendId = jsonMap['id'].toString();
            serverIds.add(backendId);
            serverVocabs.add(VocabularyModel.fromJson(jsonMap));
          }

          hasNext = pageData['has_next'] as bool;
          page++;
        }

        // Upsert all server records into Isar
        await _localDataSource.saveAll(serverVocabs);

        // Delete any local records that are not present on the server.
        await _localDataSource.deleteNotPresent(serverIds.toList());

        developer.log(
          'Sync completed: ${response.syncedCount} items pushed, '
          '${serverIds.length} items pulled.',
          name: 'SyncRepository',
        );

        return Right(response.toEntity());
      } on AuthException {
        developer.log(
          'Auth expired during sync — stopping.',
          name: 'SyncRepository',
          level: 900,
        );
        return const Left(
          AuthFailure('Session expired. Please log in again to sync.'),
        );
      } on ServerException catch (e) {
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

    return const Left(ServerFailure('Sync failed unexpectedly.'));
  }

  // ==================================================================
  //  Modern push/pull sync (POST /sync/push + GET /sync/pull)
  // ==================================================================

  @override
  Future<Either<Failure, SyncPushResponseEntity>> fullSync() async {
    // ─── Phase 1: PUSH — send local changes to server ───

    final unsyncedModels = await _localDataSource.getUnsynced();
    final unsyncedQuizResults = await _localDataSource.getUnsyncedQuizResults();

    SyncPushResponseModel? pushResponse;

    if (unsyncedModels.isNotEmpty || unsyncedQuizResults.isNotEmpty) {
      developer.log(
        'Full sync: pushing ${unsyncedModels.length} flashcards and ${unsyncedQuizResults.length} quiz attempts…',
        name: 'SyncRepository',
      );

      final pushItems = [
        ...unsyncedModels.map(SyncPushItemModel.fromVocabularyModel),
        ...unsyncedQuizResults.map(SyncPushItemModel.fromQuizResultModel),
      ];
      final pushRequest = SyncPushRequestModel(items: pushItems);

      // Attempt push with exponential backoff.
      for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
        try {
          final token = await _getTokenOrFail();
          if (token == null) {
            return const Left(
              AuthFailure('Not authenticated — sync requires login.'),
            );
          }

          pushResponse = await _remoteDataSource.pushChanges(
            request: pushRequest,
            accessToken: token,
          );

          // Process push results.
          await _processPushResults(pushResponse, unsyncedModels, unsyncedQuizResults);

          developer.log(
            'Push completed: ${pushResponse.succeededCount} succeeded, '
            '${pushResponse.failedCount} failed.',
            name: 'SyncRepository',
          );
          break; // Push succeeded, exit retry loop.
        } on AuthException {
          developer.log(
            'Auth expired during push — stopping full sync.',
            name: 'SyncRepository',
            level: 900,
          );
          return const Left(
            AuthFailure(
              'Session expired. Please log in again to sync.',
            ),
          );
        } on ServerException catch (e) {
          if (attempt < _retryDelays.length) {
            final delay = _retryDelays[attempt];
            developer.log(
              'Push attempt ${attempt + 1} failed: ${e.message}. '
              'Retrying in ${delay}s…',
              name: 'SyncRepository',
              level: 800,
            );
            await Future<void>.delayed(Duration(seconds: delay));
          } else {
            developer.log(
              'Push failed after ${_retryDelays.length + 1} attempts.',
              name: 'SyncRepository',
              level: 1000,
            );
            return Left(
              ServerFailure(
                'Push sync failed after retries: ${e.message}',
                statusCode: e.statusCode,
              ),
            );
          }
        } on CacheException catch (e) {
          return Left(CacheFailure(e.message));
        }
      }
    } else {
      developer.log(
        'Full sync: no local changes to push.',
        name: 'SyncRepository',
      );
    }

    // ─── Phase 2: PULL — fetch server changes ───

    try {
      await _pullServerChanges();
    } on AuthException {
      developer.log(
        'Auth expired during pull — stopping.',
        name: 'SyncRepository',
        level: 900,
      );
      return const Left(
        AuthFailure('Session expired. Please log in again to sync.'),
      );
    } on ServerException catch (e) {
      // Pull failure is non-fatal if push succeeded.
      developer.log(
        'Pull phase failed: ${e.message}. Push was successful.',
        name: 'SyncRepository',
        level: 800,
      );
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }

    // Build final result.
    final result = pushResponse?.toEntity() ??
        const SyncPushResponseEntity(
          succeededCount: 0,
          failedCount: 0,
          results: [],
        );

    developer.log(
      'Full sync completed: pushed=${result.succeededCount}, '
      'failed=${result.failedCount}.',
      name: 'SyncRepository',
    );

    return Right(result);
  }

  // ------------------------------------------------------------------
  //  Private helpers
  // ------------------------------------------------------------------

  /// Returns the access token or null if not authenticated.
  Future<String?> _getTokenOrFail() async {
    return await _authLocalDataSource.getAccessToken();
  }

  /// Process push results: mark synced items, update backendId.
  Future<void> _processPushResults(
    SyncPushResponseModel response,
    List<VocabularyModel> unsyncedModels,
    List<QuizResultModel> unsyncedQuizResults,
  ) async {
    final vocabIdMap = <int, String>{};
    final quizIdMap = <int, String>{};

    for (final result in response.results) {
      if (result.status == 'created' || result.status == 'updated' || result.status == 'unchanged') {
        if (result.resource == 'flashcard') {
          final localModel = unsyncedModels.where(
            (m) => m.backendId == result.clientId,
          );
          if (localModel.isNotEmpty && result.serverId != null) {
            vocabIdMap[localModel.first.id] = result.serverId.toString();
          }
        } else if (result.resource == 'quiz_attempt') {
          final localModel = unsyncedQuizResults.where(
            (m) => m.backendId == result.clientId,
          );
          if (localModel.isNotEmpty && result.serverId != null) {
            quizIdMap[localModel.first.id] = result.serverId.toString();
          }
        }
      } else if (result.status == 'failed') {
        developer.log(
          'Sync Push rejected ${result.resource} with client_id ${result.clientId}: ${result.error?['message']}',
          name: 'SyncRepository',
          level: 900,
        );
      }
    }

    if (vocabIdMap.isNotEmpty) {
      await _localDataSource.markSyncedAndUpdateId(vocabIdMap);
    }
    
    if (quizIdMap.isNotEmpty) {
      await _localDataSource.markQuizResultsSyncedAndUpdateId(quizIdMap);
    }
  }

  /// Pulls all pages of server changes via cursor-based pagination.
  ///
  /// Upserts pulled flashcard items into local Isar and persists
  /// the cursor for next sync.
  Future<void> _pullServerChanges() async {
    final token = await _getTokenOrFail();
    if (token == null) {
      throw const AuthException(message: 'Not authenticated for pull.');
    }

    var cursor = await _syncLocalDataSource.getSyncCursor();
    var totalPulled = 0;

    // Page through all available changes.
    bool hasMore = true;
    while (hasMore) {
      final pullResponse = await _remoteDataSource.pullChanges(
        cursor: cursor,
        limit: 100,
        accessToken: token,
      );

      // Process pulled items by resource type.
      final vocabModels = <VocabularyModel>[];
      final quizModels = <QuizResultModel>[];

      for (final item in pullResponse.items) {
        if (item.resource == 'flashcard') {
          try {
            vocabModels.add(
              _flashcardPayloadToVocabularyModel(item.payload),
            );
          } catch (e) {
            developer.log(
              'Skipping malformed flashcard pull item: $e',
              name: 'SyncRepository',
              level: 800,
            );
          }
        } else if (item.resource == 'quiz_attempt') {
          try {
            quizModels.add(
              _quizAttemptPayloadToQuizResultModel(item.payload),
            );
          } catch (e) {
            developer.log(
              'Skipping malformed quiz attempt pull item: $e',
              name: 'SyncRepository',
              level: 800,
            );
          }
        }
      }

      // Upsert pulled vocabularies into Isar.
      if (vocabModels.isNotEmpty) {
        await _localDataSource.saveAll(vocabModels);
      }
      
      // Upsert pulled quiz results into Isar.
      for (final q in quizModels) {
        await _localDataSource.saveQuizResult(q);
      }

      totalPulled += pullResponse.items.length;

      // Persist cursor after each page so progress is saved
      // even if the app is killed mid-sync.
      cursor = pullResponse.nextCursor;
      await _syncLocalDataSource.saveSyncCursor(cursor);

      hasMore = pullResponse.hasMore;
    }

    developer.log(
      'Pull completed: $totalPulled items received.',
      name: 'SyncRepository',
    );
  }

  /// Converts a flashcard pull payload to a [VocabularyModel].
  ///
  /// The payload structure matches the backend's
  /// `_flashcard_payload()` method in sync_service.py.
  VocabularyModel _flashcardPayloadToVocabularyModel(
    Map<String, dynamic> payload,
  ) {
    return VocabularyModel(
      backendId: payload['id'].toString(),
      word: payload['word'] as String? ?? '',
      translation: payload['translation'] as String? ?? '',
      sourceLanguage: payload['source_language'] as String,
      targetLanguage: payload['target_language'] as String,
      category: payload['category'] as String? ?? 'Chưa phân loại',
      categoryId: payload['category_id'] as int?,
      translationId: payload['translation_id'] as int?,
      masteryLevel: payload['mastery_level'] as int? ?? 0,
      lastTestedAt: payload['last_tested_at'] != null
          ? DateTime.parse(payload['last_tested_at'] as String)
          : null,
      isDeleted: payload['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(payload['created_at'] as String),
      updatedAt: DateTime.parse(payload['updated_at'] as String),
      isSynced: true, // Data pulled from server is synced.
    );
  }

  /// Converts a quiz_attempt pull payload to a [QuizResultModel].
  QuizResultModel _quizAttemptPayloadToQuizResultModel(
    Map<String, dynamic> payload,
  ) {
    return QuizResultModel(
      backendId: payload['quiz_id'].toString(),
      bankBackendId: payload['bank_id'].toString(),
      bankTitle: payload['bank_title'] as String? ?? 'N/A',
      totalQuestions: payload['total_questions'] as int? ?? 0,
      correctAnswers: payload['correct_count'] as int? ?? 0,
      score: (payload['score'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: payload['completion_time_seconds'] as int? ?? 0,
      status: payload['status'] as String? ?? 'completed',
      answers: [], // We might not get full answers in pull unless they were added to payload
      completedAt: payload['created_at'] != null
          ? DateTime.parse(payload['created_at'] as String)
          : DateTime.now(),
      isSynced: true,
    );
  }
}
