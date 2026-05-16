import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/bloc/network_cubit.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/sync_data_usecase.dart';
import 'sync_state.dart';

/// UC09 — Background Sync Worker.
///
/// This Cubit listens to [NetworkCubit] via a [StreamSubscription].
/// When the network transitions to [NetworkStatus.online]:
///   1. Gathers all Isar records with `isSynced = false`.
///   2. Sends them as a batch to `POST /api/v1/sync/vocabulary`.
///   3. Marks them as `isSynced = true` when the BE confirms success.
///
/// The sync is fully automatic — no user interaction required.
///
/// Retry behaviour is handled inside [SyncRepositoryImpl]:
/// - Exponential Backoff: 5s → 10s → 30s.
/// - Token expired → stop sync (user must re-authenticate).
class SyncCubit extends Cubit<SyncState> {
  final SyncDataUseCase _syncDataUseCase;
  final NetworkCubit _networkCubit;

  StreamSubscription<NetworkStatus>? _networkSubscription;

  /// Guards against overlapping sync cycles.
  bool _isSyncing = false;

  SyncCubit({
    required SyncDataUseCase syncDataUseCase,
    required NetworkCubit networkCubit,
  })  : _syncDataUseCase = syncDataUseCase,
        _networkCubit = networkCubit,
        super(const SyncIdle()) {
    _startListening();
  }

  // ------------------------------------------------------------------
  //  Network listener
  // ------------------------------------------------------------------

  void _startListening() {
    // If already online at creation time, trigger an initial sync.
    if (_networkCubit.state == NetworkStatus.online) {
      _triggerSync();
    }

    _networkSubscription = _networkCubit.stream.listen((status) {
      if (status == NetworkStatus.online) {
        developer.log(
          'Network came online — triggering background sync.',
          name: 'SyncCubit',
        );
        _triggerSync();
      }
    });
  }

  // ------------------------------------------------------------------
  //  Public API
  // ------------------------------------------------------------------

  /// Manually triggers a sync cycle (e.g., after a vocabulary save).
  ///
  /// If a sync is already in progress the call is silently ignored.
  void requestSync() {
    if (_networkCubit.state == NetworkStatus.online) {
      _triggerSync();
    }
  }

  // ------------------------------------------------------------------
  //  Core sync logic
  // ------------------------------------------------------------------

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    emit(const SyncSyncing());

    final result = await _syncDataUseCase(const NoParams());

    result.fold(
      (failure) {
        developer.log(
          'Background sync failed: ${failure.message}',
          name: 'SyncCubit',
          level: 900,
        );
        if (!isClosed) emit(SyncFailure(failure.message));
      },
      (response) {
        developer.log(
          'Background sync succeeded: ${response.syncedCount} items.',
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

    // Reset to idle after emitting the result so
    // the next network event can trigger a new cycle.
    if (!isClosed) emit(const SyncIdle());
    _isSyncing = false;
  }

  // ------------------------------------------------------------------
  //  Lifecycle
  // ------------------------------------------------------------------

  @override
  Future<void> close() {
    _networkSubscription?.cancel();
    return super.close();
  }
}
