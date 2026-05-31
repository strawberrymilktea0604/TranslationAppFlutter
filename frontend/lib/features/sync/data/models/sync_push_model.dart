import '../../domain/entities/sync_push_entity.dart';
import '../../../vocabulary/data/models/vocabulary_model.dart';
import '../../../vocabulary/data/models/quiz_result_model.dart';

/// DTO for a single item in a push sync request.
///
/// Maps from local Isar models (e.g., [VocabularyModel]) to the
/// JSON payload expected by `POST /api/v1/sync/push`.
class SyncPushItemModel {
  final String resource;
  final String clientId;
  final int? serverId;
  final DateTime updatedAt;
  final Map<String, dynamic> payload;

  const SyncPushItemModel({
    required this.resource,
    required this.clientId,
    this.serverId,
    required this.updatedAt,
    required this.payload,
  });

  /// Creates a push item from a local [VocabularyModel].
  ///
  /// Maps vocabulary fields to the `FlashcardPushPayload` schema
  /// expected by the backend.
  factory SyncPushItemModel.fromVocabularyModel(VocabularyModel m) {
    // If backendId is a numeric string, it's a server-assigned ID.
    final int? sId = int.tryParse(m.backendId);

    return SyncPushItemModel(
      resource: 'flashcard',
      clientId: m.backendId,
      serverId: sId,
      updatedAt: m.updatedAt,
      payload: {
        'word': m.word,
        'translation': m.translation,
        'source_language': m.sourceLanguage,
        'target_language': m.targetLanguage,
        'category_id': m.categoryId,
        'category': m.category,
        'mastery_level': m.masteryLevel,
        'last_tested_at': m.lastTestedAt?.toUtc().toIso8601String(),
        'is_deleted': m.isDeleted,
        'created_at': m.createdAt.toUtc().toIso8601String(),
      },
    );
  }

  /// Creates a push item from a local [QuizResultModel].
  factory SyncPushItemModel.fromQuizResultModel(QuizResultModel m) {
    final int? sId = int.tryParse(m.backendId);

    return SyncPushItemModel(
      resource: 'quiz_attempt',
      clientId: m.backendId,
      serverId: sId,
      updatedAt: m.completedAt,
      payload: {
        'bank_id': int.tryParse(m.bankBackendId) ?? 0,
        'time_spent_seconds': m.durationSeconds,
        'created_at': m.completedAt.toUtc().toIso8601String(),
        'answers': m.answers.map((a) => {
          'question_id': int.tryParse(a.questionBackendId) ?? 0,
          'selected_answer': a.selectedAnswer,
        }).toList(),
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resource': resource,
      'client_id': clientId,
      'server_id': serverId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'payload': payload,
    };
  }

  SyncPushItemEntity toEntity() {
    return SyncPushItemEntity(
      resource: SyncResource.fromApiString(resource),
      clientId: clientId,
      serverId: serverId,
      updatedAt: updatedAt,
      payload: payload,
    );
  }
}

/// DTO for the batch push request body.
class SyncPushRequestModel {
  final List<SyncPushItemModel> items;

  const SyncPushRequestModel({required this.items});

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

/// DTO for a single item in the push response.
class SyncPushResultItemModel {
  final String resource;
  final String clientId;
  final int? serverId;
  final String status;
  final DateTime? serverUpdatedAt;
  final Map<String, dynamic>? canonical;
  final Map<String, dynamic>? error;

  const SyncPushResultItemModel({
    required this.resource,
    required this.clientId,
    this.serverId,
    required this.status,
    this.serverUpdatedAt,
    this.canonical,
    this.error,
  });

  factory SyncPushResultItemModel.fromJson(Map<String, dynamic> json) {
    return SyncPushResultItemModel(
      resource: json['resource'] as String,
      clientId: json['client_id'] as String,
      serverId: json['server_id'] as int?,
      status: json['status'] as String,
      serverUpdatedAt: json['server_updated_at'] != null
          ? DateTime.parse(json['server_updated_at'] as String)
          : null,
      canonical: json['canonical'] as Map<String, dynamic>?,
      error: json['error'] as Map<String, dynamic>?,
    );
  }

  SyncPushResultItemEntity toEntity() {
    return SyncPushResultItemEntity(
      resource: SyncResource.fromApiString(resource),
      clientId: clientId,
      serverId: serverId,
      status: status,
      serverUpdatedAt: serverUpdatedAt,
      canonical: canonical,
      errorCode: error?['code'] as String?,
      errorMessage: error?['message'] as String?,
    );
  }
}

/// DTO for the full push response.
class SyncPushResponseModel {
  final int succeededCount;
  final int failedCount;
  final List<SyncPushResultItemModel> results;

  const SyncPushResponseModel({
    required this.succeededCount,
    required this.failedCount,
    required this.results,
  });

  factory SyncPushResponseModel.fromJson(Map<String, dynamic> json) {
    return SyncPushResponseModel(
      succeededCount: json['succeeded_count'] as int,
      failedCount: json['failed_count'] as int,
      results: (json['results'] as List)
          .map(
            (r) => SyncPushResultItemModel.fromJson(
              r as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  SyncPushResponseEntity toEntity() {
    return SyncPushResponseEntity(
      succeededCount: succeededCount,
      failedCount: failedCount,
      results: results.map((r) => r.toEntity()).toList(),
    );
  }
}
