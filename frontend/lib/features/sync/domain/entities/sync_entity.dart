import 'package:equatable/equatable.dart';

/// UC09 — Entity representing the result of a single vocabulary sync operation.
///
/// Each item maps a [clientId] (temporary local ID) to a [serverId]
/// (server-assigned ID) along with the sync [status].
class SyncResultEntity extends Equatable {
  /// The client-side ID that was sent in the sync request.
  final String clientId;

  /// The server-assigned ID for this record.
  final int serverId;

  /// One of: `created`, `updated`, `unchanged`.
  final String status;

  /// If status is `unchanged`, this holds the server's updated_at
  /// so the client can reconcile.
  final DateTime? serverUpdatedAt;

  const SyncResultEntity({
    required this.clientId,
    required this.serverId,
    required this.status,
    this.serverUpdatedAt,
  });

  @override
  List<Object?> get props => [clientId, serverId, status, serverUpdatedAt];
}

/// UC09 — Entity representing the full response of a batch sync operation.
class SyncResponseEntity extends Equatable {
  /// Number of records that were actually synced (created or updated).
  final int syncedCount;

  /// Per-item sync results.
  final List<SyncResultEntity> results;

  const SyncResponseEntity({
    required this.syncedCount,
    required this.results,
  });

  @override
  List<Object?> get props => [syncedCount, results];
}
