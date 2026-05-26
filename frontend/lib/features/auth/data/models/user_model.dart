import 'package:isar_community/isar.dart';
import '../../domain/entities/user_entity.dart';

part 'user_model.g.dart';

@collection
class UserModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String backendId;

  late String email;
  String? name;
  String? avatarUrl;
  late String role;
  late String status;
  late DateTime createdAt;

  // Constructor
  UserModel({
    required this.backendId,
    required this.email,
    this.name,
    this.avatarUrl,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  // Empty constructor for Isar
  UserModel.isar();

  // Mapper to Entity
  UserEntity toEntity() {
    return UserEntity(
      id: backendId,
      email: email,
      name: name,
      avatarUrl: avatarUrl,
      role: role,
      status: status,
      createdAt: createdAt,
    );
  }

  // Mapper from Entity
  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      backendId: entity.id,
      email: entity.email,
      name: entity.name,
      avatarUrl: entity.avatarUrl,
      role: entity.role,
      status: entity.status,
      createdAt: entity.createdAt,
    );
  }

  // JSON serialization
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      backendId: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'user',
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': backendId,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'role': role,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

