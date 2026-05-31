import 'package:equatable/equatable.dart';

import '../../domain/entities/sync_entity.dart';
import '../../domain/entities/sync_push_entity.dart';

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
///
/// Optionally carries a [phase] description for UI progress display.
class SyncSyncing extends SyncState {
  /// Human-readable description of the current phase.
  /// e.g., 'Pushing changes…', 'Pulling updates…'
  final String? phase;

  const SyncSyncing({this.phase});

  @override
  List<Object?> get props => [phase];
}

/// The most recent sync completed successfully.
class SyncSuccess extends SyncState {
  /// Number of items that were synced.
  final int syncedCount;

  /// Detailed per-item results (legacy sync).
  final List<SyncResultEntity> results;

  /// Push response results (modern sync), if available.
  final SyncPushResponseEntity? pushResponse;

  /// Timestamp of this sync completion.
  final DateTime completedAt;

  SyncSuccess({
    required this.syncedCount,
    required this.results,
    this.pushResponse,
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();

  @override
  List<Object?> get props => [
        syncedCount,
        results,
        pushResponse,
        completedAt,
      ];
}

/// The most recent sync failed.
class SyncFailure extends SyncState {
  final String message;

  const SyncFailure(this.message);

  @override
  List<Object?> get props => [message];
}
