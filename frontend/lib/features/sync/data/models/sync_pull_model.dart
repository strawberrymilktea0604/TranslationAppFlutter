import '../../domain/entities/sync_pull_entity.dart';
import '../../domain/entities/sync_push_entity.dart';

/// DTO for a single item in the pull response.
///
/// Maps from the JSON returned by `GET /api/v1/sync/pull`
/// to a domain entity.
class SyncPullItemModel {
  final String resource;
  final int serverId;
  final DateTime updatedAt;
  final Map<String, dynamic> payload;

  const SyncPullItemModel({
    required this.resource,
    required this.serverId,
    required this.updatedAt,
    required this.payload,
  });

  factory SyncPullItemModel.fromJson(Map<String, dynamic> json) {
    return SyncPullItemModel(
      resource: json['resource'] as String,
      serverId: json['server_id'] as int,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      payload: json['payload'] as Map<String, dynamic>,
    );
  }

  SyncPullItemEntity toEntity() {
    return SyncPullItemEntity(
      resource: SyncResource.fromApiString(resource),
      serverId: serverId,
      updatedAt: updatedAt,
      payload: payload,
    );
  }
}

/// DTO for the full pull response with cursor-based pagination.
class SyncPullResponseModel {
  final List<SyncPullItemModel> items;
  final String nextCursor;
  final bool hasMore;

  const SyncPullResponseModel({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory SyncPullResponseModel.fromJson(Map<String, dynamic> json) {
    return SyncPullResponseModel(
      items: (json['items'] as List)
          .map(
            (i) => SyncPullItemModel.fromJson(
              i as Map<String, dynamic>,
            ),
          )
          .toList(),
      nextCursor: json['next_cursor'] as String,
      hasMore: json['has_more'] as bool,
    );
  }

  SyncPullResponseEntity toEntity() {
    return SyncPullResponseEntity(
      items: items.map((i) => i.toEntity()).toList(),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }
}
