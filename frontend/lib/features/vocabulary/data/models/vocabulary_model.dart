import 'package:isar/isar.dart';
import '../../domain/entities/vocabulary_entity.dart';

part 'vocabulary_model.g.dart';

@collection
class VocabularyModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String backendId;

  late String word;
  late String translation;
  late String sourceLanguage;
  late String targetLanguage;

  /// Category for flashcard grouping (e.g. "Weather", "Medical Health").
  /// Defaults to "Chưa phân loại" when not set.
  @Index()
  late String category;

  /// Whether the user has starred/favorited this word.
  late bool isStarred;

  /// Optional IPA pronunciation.
  String? pronunciation;

  /// Optional example sentence.
  String? example;

  /// Reference to the backend translation record that created this entry.
  /// Nullable because offline-created entries won't have one until synced.
  int? translationId;

  /// Mastery level for spaced-repetition tracking (0–5).
  /// 0 = new, 5 = fully mastered.
  late int masteryLevel;

  /// When this word was last reviewed/tested.
  DateTime? lastTestedAt;

  @Index()
  late DateTime createdAt;
  late DateTime updatedAt;

  late bool isSynced;
  late bool isDeleted;

  VocabularyModel({
    required this.backendId,
    required this.word,
    required this.translation,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.createdAt,
    required this.updatedAt,
    this.category = 'Chưa phân loại',
    this.isStarred = false,
    this.pronunciation,
    this.example,
    this.translationId,
    this.masteryLevel = 0,
    this.lastTestedAt,
    this.isSynced = false,
    this.isDeleted = false,
  });

  VocabularyModel.isar();

  VocabularyEntity toEntity() {
    return VocabularyEntity(
      id: backendId,
      word: word,
      translation: translation,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      category: category,
      isStarred: isStarred,
      pronunciation: pronunciation,
      example: example,
      translationId: translationId,
      masteryLevel: masteryLevel,
      lastTestedAt: lastTestedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isSynced: isSynced,
      isDeleted: isDeleted,
    );
  }

  factory VocabularyModel.fromEntity(VocabularyEntity entity) {
    return VocabularyModel(
      backendId: entity.id,
      word: entity.word,
      translation: entity.translation,
      sourceLanguage: entity.sourceLanguage,
      targetLanguage: entity.targetLanguage,
      category: entity.category,
      isStarred: entity.isStarred,
      pronunciation: entity.pronunciation,
      example: entity.example,
      translationId: entity.translationId,
      masteryLevel: entity.masteryLevel,
      lastTestedAt: entity.lastTestedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isSynced: entity.isSynced,
      isDeleted: entity.isDeleted,
    );
  }

  factory VocabularyModel.fromJson(Map<String, dynamic> json) {
    return VocabularyModel(
      backendId: json['id'] as String,
      word: json['word'] as String? ?? json['source_text'] as String? ?? '',
      translation: json['translation'] as String? ?? json['translated_text'] as String? ?? '',
      sourceLanguage: json['source_language'] as String,
      targetLanguage: json['target_language'] as String,
      category: json['category'] as String? ?? 'Chưa phân loại',
      isStarred: json['is_starred'] as bool? ?? false,
      pronunciation: json['pronunciation'] as String?,
      example: json['example'] as String?,
      translationId: json['translation_id'] as int?,
      masteryLevel: json['mastery_level'] as int? ?? 0,
      lastTestedAt: json['last_tested_at'] != null
          ? DateTime.parse(json['last_tested_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isSynced: true,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': backendId,
      'word': word,
      'translation': translation,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'category': category,
      'is_starred': isStarred,
      'pronunciation': pronunciation,
      'example': example,
      'translation_id': translationId,
      'mastery_level': masteryLevel,
      'last_tested_at': lastTestedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }
}
