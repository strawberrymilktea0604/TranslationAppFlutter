import 'package:equatable/equatable.dart';

/// Represents the type of resource being synced.
///
/// Maps to the backend `SyncResource` literal type.
enum SyncResource {
  flashcard,
  quizAttempt;

  /// Converts to the snake_case string expected by the backend API.
  String toApiString() {
    switch (this) {
      case SyncResource.flashcard:
        return 'flashcard';
      case SyncResource.quizAttempt:
        return 'quiz_attempt';
    }
  }

  /// Parses from the snake_case string returned by the backend API.
  static SyncResource fromApiString(String value) {
    switch (value) {
      case 'flashcard':
        return SyncResource.flashcard;
      case 'quiz_attempt':
        return SyncResource.quizAttempt;
      default:
        throw ArgumentError('Unknown SyncResource: $value');
    }
  }
}

/// A single item to be pushed to the backend via `POST /api/v1/sync/push`.
class SyncPushItemEntity extends Equatable {
  /// The type of resource (flashcard or quiz_attempt).
  final SyncResource resource;

  /// Client-side ID for this record.
  final String clientId;

  /// Server-assigned ID, if known (null for new records).
  final int? serverId;

  /// Last modified timestamp on the client.
  final DateTime updatedAt;

  /// Resource-specific payload (word, translation, etc.).
  final Map<String, dynamic> payload;

  const SyncPushItemEntity({
    required this.resource,
    required this.clientId,
    this.serverId,
    required this.updatedAt,
    required this.payload,
  });

  @override
  List<Object?> get props => [resource, clientId, serverId, updatedAt];
}

/// Result for a single item after push sync.
class SyncPushResultItemEntity extends Equatable {
  /// The type of resource.
  final SyncResource resource;

  /// The client-side ID that was sent.
  final String clientId;

  /// Server-assigned ID (may be new for created items).
  final int? serverId;

  /// One of: `created`, `updated`, `unchanged`, `failed`.
  final String status;

  /// The server's updated_at for conflict resolution.
  final DateTime? serverUpdatedAt;

  /// Canonical server data for this record (used to update local).
  final Map<String, dynamic>? canonical;

  /// Error details if status is `failed`.
  final String? errorCode;
  final String? errorMessage;

  const SyncPushResultItemEntity({
    required this.resource,
    required this.clientId,
    this.serverId,
    required this.status,
    this.serverUpdatedAt,
    this.canonical,
    this.errorCode,
    this.errorMessage,
  });

  /// Whether this item was successfully synced.
  bool get isSuccess =>
      status == 'created' ||
      status == 'updated' ||
      status == 'unchanged';

  @override
  List<Object?> get props => [
        resource,
        clientId,
        serverId,
        status,
        serverUpdatedAt,
      ];
}

/// Full response from `POST /api/v1/sync/push`.
class SyncPushResponseEntity extends Equatable {
  /// Number of items that succeeded.
  final int succeededCount;

  /// Number of items that failed.
  final int failedCount;

  /// Per-item results.
  final List<SyncPushResultItemEntity> results;

  const SyncPushResponseEntity({
    required this.succeededCount,
    required this.failedCount,
    required this.results,
  });

  @override
  List<Object?> get props => [succeededCount, failedCount, results];
}
