import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_error_message.dart';
import '../../../../core/network/bloc/network_cubit.dart';
import '../../../../core/network/services/realtime_sync_service.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../domain/usecases/full_sync_usecase.dart';
import '../../domain/usecases/sync_data_usecase.dart';
import 'sync_state.dart';
import '../../../../injection_container.dart';

/// UC09 — Background Sync Worker.
///
/// This Cubit listens to [NetworkCubit] via a [StreamSubscription].
/// When the network transitions to [NetworkStatus.online]:
///   1. Gathers all Isar records with `isSynced = false`.
///   2. Pushes them via `POST /api/v1/sync/push`.
///   3. Pulls server changes via `GET /api/v1/sync/pull`.
///   4. Upserts pulled items into local Isar.
///
/// Additionally, it opens a WebSocket connection ([RealtimeSyncService])
/// so the server can push `sync_completed` events in real time.
/// Flutter tabs subscribe to [syncCompletedStream] to refresh their lists.
///
/// The sync is fully automatic — no user interaction required.
///
/// Retry behaviour is handled inside [SyncRepositoryImpl]:
/// - Exponential Backoff: 5s → 10s → 30s.
/// - Token expired → stop sync (user must re-authenticate).
class SyncCubit extends Cubit<SyncState> {
  final SyncDataUseCase _syncDataUseCase;
  final FullSyncUseCase _fullSyncUseCase;
  final NetworkCubit _networkCubit;
  final RealtimeSyncService _realtimeSyncService;

  StreamSubscription<NetworkStatus>? _networkSubscription;
  StreamSubscription<SyncCompletedEvent>? _wsSubscription;

  /// Broadcast stream of realtime sync events.
  /// Vocabulary page and History tab listen to this.
  Stream<SyncCompletedEvent> get syncCompletedStream =>
      _realtimeSyncService.syncEvents;

  /// Guards against overlapping sync cycles.
  bool _isSyncing = false;

  SyncCubit({
    required SyncDataUseCase syncDataUseCase,
    required FullSyncUseCase fullSyncUseCase,
    required NetworkCubit networkCubit,
    required RealtimeSyncService realtimeSyncService,
  })  : _syncDataUseCase = syncDataUseCase,
        _fullSyncUseCase = fullSyncUseCase,
        _networkCubit = networkCubit,
        _realtimeSyncService = realtimeSyncService,
        super(const SyncIdle()) {
    _startListening();
    _connectWebSocket();
  }

  // ------------------------------------------------------------------
  //  Network listener
  // ------------------------------------------------------------------

  void _startListening() {
    // If already online at creation time, trigger an initial sync.
    if (_networkCubit.state == NetworkStatus.online) {
      _triggerFullSync();
    }

    _networkSubscription = _networkCubit.stream.listen((status) {
      if (status == NetworkStatus.online) {
        developer.log(
          'Network came online — triggering background sync.',
          name: 'SyncCubit',
        );
        _triggerFullSync();
        // Re-connect WebSocket if it dropped while offline.
        _connectWebSocket();
      }
    });
  }

  // ------------------------------------------------------------------
  //  WebSocket connection
  // ------------------------------------------------------------------

  Future<void> _connectWebSocket() async {
    try {
      final authLocal = sl<AuthLocalDataSource>();
      final token = await authLocal.getAccessToken();
      if (token == null || token.isEmpty) return;

      await _realtimeSyncService.connect(token);

      // Cancel any existing subscription before creating a new one.
      await _wsSubscription?.cancel();
      _wsSubscription = _realtimeSyncService.syncEvents.listen(
        (event) {
          developer.log(
            'WS sync_completed received: ${event.syncedCount} items',
            name: 'SyncCubit',
          );
          // Emit a transient SyncSuccess so the VocabularyPage listener
          // can reload both tabs, then immediately return to idle.
          if (!isClosed) {
            emit(SyncSuccess(
              syncedCount: event.syncedCount,
              results: const [],
            ));
            emit(const SyncIdle());
          }
        },
        onError: (e) =>
            developer.log('WS stream error: $e', name: 'SyncCubit'),
      );
    } catch (e) {
      developer.log('WS connect error: $e', name: 'SyncCubit');
    }
  }

  /// Call this after a successful login to connect the WebSocket.
  Future<void> connectWebSocketWithToken(String token) async {
    await _realtimeSyncService.connect(token);
  }

  // ------------------------------------------------------------------
  //  Public API
  // ------------------------------------------------------------------

  /// Manually triggers a full sync cycle (push + pull).
  ///
  /// If a sync is already in progress the call is silently ignored.
  void requestSync() {
    if (_networkCubit.state == NetworkStatus.online) {
      _triggerFullSync();
    }
  }

  /// Triggers a legacy vocabulary-only sync cycle.
  ///
  /// Kept for backward compatibility with existing callers.
  void requestLegacySync() {
    if (_networkCubit.state == NetworkStatus.online) {
      _triggerLegacySync();
    }
  }

  // ------------------------------------------------------------------
  //  Core sync logic — Modern push/pull
  // ------------------------------------------------------------------

  Future<void> _triggerFullSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    emit(const SyncSyncing(phase: 'Đang đồng bộ…'));

    final result = await _fullSyncUseCase(const NoParams());

    result.fold(
      (failure) {
        developer.log(
          'Full sync failed: ${failure.message}',
          name: 'SyncCubit',
          level: 900,
        );
        if (!isClosed) emit(SyncFailure(AppErrorMessage.fromFailure(failure)));
      },
      (response) {
        developer.log(
          'Full sync succeeded: ${response.succeededCount} pushed.',
          name: 'SyncCubit',
        );
        if (!isClosed) {
          emit(SyncSuccess(
            syncedCount: response.succeededCount,
            results: const [],
            pushResponse: response,
          ));
        }
      },
    );

    // Reset to idle after emitting the result so
    // the next network event can trigger a new cycle.
    if (!isClosed) emit(const SyncIdle());
    _isSyncing = false;
  }

  // ------------------------------------------------------------------
  //  Core sync logic — Legacy vocabulary-only
  // ------------------------------------------------------------------

  Future<void> _triggerLegacySync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    emit(const SyncSyncing(phase: 'Đang đồng bộ từ vựng…'));

    final result = await _syncDataUseCase(const NoParams());

    result.fold(
      (failure) {
        developer.log(
          'Legacy sync failed: ${failure.message}',
          name: 'SyncCubit',
          level: 900,
        );
        if (!isClosed) emit(SyncFailure(AppErrorMessage.fromFailure(failure)));
      },
      (response) {
        developer.log(
          'Legacy sync succeeded: ${response.syncedCount} items.',
          name: 'SyncCubit',
        );
        if (!isClosed) {
          emit(SyncSuccess(
            syncedCount: response.syncedCount,
            results: response.results,
          ));
        }
      },
    );

    if (!isClosed) emit(const SyncIdle());
    _isSyncing = false;
  }

  // ------------------------------------------------------------------
  //  Lifecycle
  // ------------------------------------------------------------------

  @override
  Future<void> close() async {
    await _networkSubscription?.cancel();
    await _wsSubscription?.cancel();
    await _realtimeSyncService.disconnect();
    return super.close();
  }
}
