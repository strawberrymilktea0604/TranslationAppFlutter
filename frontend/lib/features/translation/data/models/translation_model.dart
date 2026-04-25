import 'package:frontend/features/translation/domain/entities/translation_entity.dart';

/// DTO for translation API responses.
/// Extends [TranslationEntity] so it can be used directly where an entity
/// is expected, and provides fromJson/toEntity helpers.
class TranslationModel extends TranslationEntity {
  const TranslationModel({
    required super.id,
    required super.sourceText,
    required super.translatedText,
    required super.sourceLanguage,
    required super.targetLanguage,
    required super.createdAt,
    required super.updatedAt,
    super.isSynced,
    super.isDeleted,
  });

  factory TranslationModel.fromJson(Map<String, dynamic> json) {
    return TranslationModel(
      id: json['id']?.toString() ?? '',
      sourceText: (json['sourceText'] ?? json['source_text'] ?? '') as String,
      translatedText:
          (json['translatedText'] ?? json['translated_text'] ?? '') as String,
      sourceLanguage:
          (json['sourceLanguage'] ?? json['source_language'] ?? '') as String,
      targetLanguage:
          (json['targetLanguage'] ?? json['target_language'] ?? '') as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      isSynced: (json['isSynced'] ?? json['is_synced'] ?? false) as bool,
      isDeleted: (json['isDeleted'] ?? json['is_deleted'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceText': sourceText,
    'translatedText': translatedText,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isSynced': isSynced,
    'isDeleted': isDeleted,
  };

  TranslationEntity toEntity() => TranslationEntity(
    id: id,
    sourceText: sourceText,
    translatedText: translatedText,
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isSynced: isSynced,
    isDeleted: isDeleted,
  );
}
