// Vocabulary model for Flutter app.
// Contains VocabularyDetail and VocabularyListResponse classes.

class VocabularyDetail {
  final int id;
  final int userId;
  final int translationId;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Translation details
  final String sourceLanguage;
  final String targetLanguage;
  final String sourceText;
  final String translatedText;
  final String? translationType;
  final DateTime? translationCreatedAt;

  VocabularyDetail({
    required this.id,
    required this.userId,
    required this.translationId,
    required this.isDeleted,
    required this.createdAt,
    this.updatedAt,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sourceText,
    required this.translatedText,
    this.translationType,
    this.translationCreatedAt,
  });

  factory VocabularyDetail.fromJson(Map<String, dynamic> json) {
    return VocabularyDetail(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      translationId: json['translation_id'] as int,
      isDeleted: json['is_deleted'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      sourceLanguage: json['source_language'] as String,
      targetLanguage: json['target_language'] as String,
      sourceText: json['source_text'] as String,
      translatedText: json['translated_text'] as String,
      translationType: json['translation_type'] as String?,
      translationCreatedAt: json['translation_created_at'] != null
          ? DateTime.parse(json['translation_created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'translation_id': translationId,
    'is_deleted': isDeleted,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'source_language': sourceLanguage,
    'target_language': targetLanguage,
    'source_text': sourceText,
    'translated_text': translatedText,
    'translation_type': translationType,
    'translation_created_at': translationCreatedAt?.toIso8601String(),
  };
}

class VocabularyListResponse {
  final List<VocabularyDetail> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  VocabularyListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory VocabularyListResponse.fromJson(Map<String, dynamic> json) {
    return VocabularyListResponse(
      items: List<VocabularyDetail>.from(
        (json['items'] as List).map(
          (x) => VocabularyDetail.fromJson(x as Map<String, dynamic>),
        ),
      ),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      totalPages: json['total_pages'] as int,
      hasNext: json['has_next'] as bool,
      hasPrev: json['has_prev'] as bool,
    );
  }
}
