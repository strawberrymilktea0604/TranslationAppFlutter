import 'package:isar/isar.dart';
import '../../domain/entities/history_entity.dart';

part 'history_model.g.dart';

@collection
class HistoryModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String backendId;

  late String sourceText;
  late String translatedText;
  late String sourceLanguage;
  late String targetLanguage;

  @Index()
  late DateTime createdAt;
  late DateTime updatedAt;

  late bool isSynced;
  late bool isDeleted;

  HistoryModel({
    required this.backendId,
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
  });

  HistoryModel.isar();

  HistoryEntity toEntity() {
    return HistoryEntity(
      isarId: id, // Isar auto-increment integer
      id: backendId,
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

  factory HistoryModel.fromEntity(HistoryEntity entity) {
    return HistoryModel(
      backendId: entity.id,
      sourceText: entity.sourceText,
      translatedText: entity.translatedText,
      sourceLanguage: entity.sourceLanguage,
      targetLanguage: entity.targetLanguage,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isSynced: entity.isSynced,
      isDeleted: entity.isDeleted,
    );
  }

  factory HistoryModel.fromJson(Map<String, dynamic> json) {
    return HistoryModel(
      backendId: json['id'] as String,
      sourceText: json['source_text'] as String,
      translatedText: json['translated_text'] as String,
      sourceLanguage: json['source_language'] as String,
      targetLanguage: json['target_language'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isSynced: true, // Data from server is considered synced
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': backendId,
      'source_text': sourceText,
      'translated_text': translatedText,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }
}
