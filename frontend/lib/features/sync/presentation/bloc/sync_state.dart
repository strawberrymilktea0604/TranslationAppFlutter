import 'package:equatable/equatable.dart';

import '../../domain/entities/sync_entity.dart';

/// States for the SyncCubit (Background Sync Worker).
///
/// State flow:
///   Idle → Syncing → SyncSuccess / SyncFailure → Idle
sealed class SyncState extends Equatable {
  const SyncState();

  @override
  List<Object?> get props => [];
}

/// No sync operation in progress.
class SyncIdle extends SyncState {
  const SyncIdle();
}

/// A background sync is currently in progress.
class SyncSyncing extends SyncState {
  const SyncSyncing();
}

/// The most recent sync completed successfully.
class SyncSuccess extends SyncState {
  /// Number of items that were synced.
  final int syncedCount;

  /// Detailed per-item results.
  final List<SyncResultEntity> results;

  const SyncSuccess({
    required this.syncedCount,
    required this.results,
  });

  @override
  List<Object?> get props => [syncedCount, results];
}

/// The most recent sync failed.
class SyncFailure extends SyncState {
  final String message;

  const SyncFailure(this.message);

  @override
  List<Object?> get props => [message];
}
