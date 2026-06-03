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

  /// Parses a JSON map into a [TranslationModel].
  ///
  /// Handles both camelCase (Dart convention) and snake_case
  /// (backend convention from `/translate/text`).
  factory TranslationModel.fromJson(Map<String, dynamic> json) {
    final rawSourceLanguage =
        (json['source_language'] ?? json['sourceLanguage'] ?? '') as String;
    final detectedSourceLanguage =
        (json['detected_source_language'] ?? json['detectedSourceLanguage'])
            as String?;
    final resolvedSourceLanguage =
        rawSourceLanguage.toLowerCase() == 'auto' &&
            detectedSourceLanguage != null &&
            detectedSourceLanguage.trim().isNotEmpty
        ? detectedSourceLanguage.trim().toLowerCase()
        : rawSourceLanguage;

    return TranslationModel(
      id: json['id']?.toString() ?? '',
      sourceText: (json['source_text'] ?? json['sourceText'] ?? '') as String,
      translatedText:
          (json['translated_text'] ?? json['translatedText'] ?? '') as String,
      sourceLanguage: resolvedSourceLanguage,
      targetLanguage:
          (json['target_language'] ?? json['targetLanguage'] ?? '') as String,
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
      isSynced: (json['is_synced'] ?? json['isSynced'] ?? false) as bool,
      isDeleted: (json['is_deleted'] ?? json['isDeleted'] ?? false) as bool,
    );
  }

  /// Safely parses a datetime value that may be null or a string.
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
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
