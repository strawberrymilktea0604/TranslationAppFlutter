import 'package:equatable/equatable.dart';

import 'sync_push_entity.dart';

/// A single item received from the server via `GET /api/v1/sync/pull`.
class SyncPullItemEntity extends Equatable {
  /// The type of resource (flashcard or quiz_attempt).
  final SyncResource resource;

  /// Server-assigned ID.
  final int serverId;

  /// When this record was last modified on the server.
  final DateTime updatedAt;

  /// Resource-specific payload.
  final Map<String, dynamic> payload;

  const SyncPullItemEntity({
    required this.resource,
    required this.serverId,
    required this.updatedAt,
    required this.payload,
  });

  @override
  List<Object?> get props => [resource, serverId, updatedAt];
}

/// Full response from `GET /api/v1/sync/pull`.
///
/// Uses cursor-based pagination. The client must persist
/// [nextCursor] and pass it in the next pull request to
/// receive only new changes since the last pull.
class SyncPullResponseEntity extends Equatable {
  /// Items changed since the last cursor.
  final List<SyncPullItemEntity> items;

  /// Opaque cursor to pass in the next pull request.
  final String nextCursor;

  /// Whether there are more pages to fetch.
  final bool hasMore;

  const SyncPullResponseEntity({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  @override
  List<Object?> get props => [items, nextCursor, hasMore];
}
