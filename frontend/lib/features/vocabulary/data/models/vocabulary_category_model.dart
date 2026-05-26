import 'package:isar_community/isar.dart';
import '../../domain/entities/vocabulary_category_entity.dart';

part 'vocabulary_category_model.g.dart';

@collection
class VocabularyCategoryModel {
  Id id = Isar.autoIncrement; // Isar auto-increment ID

  @Index(unique: true, replace: true)
  late int backendId; // Backend ID

  late String name;

  @Index()
  late DateTime createdAt;
  late DateTime updatedAt;

  late bool isSynced;
  late bool isDeleted;

  VocabularyCategoryModel({
    required this.backendId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
  });

  VocabularyCategoryModel.isar();

  VocabularyCategoryEntity toEntity() {
    return VocabularyCategoryEntity(
      isarId: id,
      id: backendId,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isSynced: isSynced,
      isDeleted: isDeleted,
    );
  }

  factory VocabularyCategoryModel.fromEntity(VocabularyCategoryEntity entity) {
    return VocabularyCategoryModel(
      backendId: entity.id,
      name: entity.name,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isSynced: entity.isSynced,
      isDeleted: entity.isDeleted,
    );
  }

  factory VocabularyCategoryModel.fromJson(Map<String, dynamic> json) {
    return VocabularyCategoryModel(
      backendId: json['id'] as int,
      name: json['name'] as String,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
      isSynced: true,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': backendId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }
}
