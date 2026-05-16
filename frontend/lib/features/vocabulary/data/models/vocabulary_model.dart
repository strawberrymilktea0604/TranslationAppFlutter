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
    this.isSynced = false,
    this.isDeleted = false,
  });

  VocabularyModel.isar();

  VocabularyEntity toEntity() {
    return VocabularyEntity(
      isarId: id,
      id: backendId,
      word: word,
      translation: translation,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
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
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isSynced: entity.isSynced,
      isDeleted: entity.isDeleted,
    );
  }

  factory VocabularyModel.fromJson(Map<String, dynamic> json) {
    return VocabularyModel(
      backendId: json['id'] as String,
      word: json['word'] as String,
      translation: json['translation'] as String,
      sourceLanguage: json['source_language'] as String,
      targetLanguage: json['target_language'] as String,
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }
}
