import '../../../vocabulary/data/models/vocabulary_model.dart';
import '../../domain/entities/sync_entity.dart';

/// DTO for a single vocabulary item in a sync batch request.
///
/// Maps from [VocabularyModel] (Isar) to the JSON payload
/// expected by `POST /api/v1/sync/vocabulary`.
class SyncVocabularyItemModel {
  final String clientId;
  final String word;
  final String translation;
  final String sourceLanguage;
  final String targetLanguage;
  final int? categoryId;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SyncVocabularyItemModel({
    required this.clientId,
    required this.word,
    required this.translation,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.categoryId,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a sync item from a local [VocabularyModel].
  factory SyncVocabularyItemModel.fromVocabularyModel(VocabularyModel m) {
    return SyncVocabularyItemModel(
      clientId: m.backendId,
      word: m.word,
      translation: m.translation,
      sourceLanguage: m.sourceLanguage,
      targetLanguage: m.targetLanguage,
      categoryId: m.categoryId,
      isDeleted: m.isDeleted,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'word': word,
      'translation': translation,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'category_id': categoryId,
      'is_deleted': isDeleted,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

/// DTO for the batch sync request body.
class SyncVocabularyRequestModel {
  final List<SyncVocabularyItemModel> items;

  const SyncVocabularyRequestModel({required this.items});

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

/// DTO for a single item in the sync response.
class SyncResultItemModel {
  final String clientId;
  final int serverId;
  final String status;
  final DateTime? serverUpdatedAt;

  const SyncResultItemModel({
    required this.clientId,
    required this.serverId,
    required this.status,
    this.serverUpdatedAt,
  });

  factory SyncResultItemModel.fromJson(Map<String, dynamic> json) {
    return SyncResultItemModel(
      clientId: json['client_id'] as String,
      serverId: json['server_id'] as int,
      status: json['status'] as String,
      serverUpdatedAt: json['server_updated_at'] != null
          ? DateTime.parse(json['server_updated_at'] as String)
          : null,
    );
  }

  SyncResultEntity toEntity() {
    return SyncResultEntity(
      clientId: clientId,
      serverId: serverId,
      status: status,
      serverUpdatedAt: serverUpdatedAt,
    );
  }
}

/// DTO for the full sync response.
class SyncResponseModel {
  final int syncedCount;
  final List<SyncResultItemModel> results;

  const SyncResponseModel({
    required this.syncedCount,
    required this.results,
  });

  factory SyncResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return SyncResponseModel(
      syncedCount: data['synced_count'] as int,
      results: (data['results'] as List)
          .map(
            (r) =>
                SyncResultItemModel.fromJson(r as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  SyncResponseEntity toEntity() {
    return SyncResponseEntity(
      syncedCount: syncedCount,
      results: results.map((r) => r.toEntity()).toList(),
    );
  }
}
