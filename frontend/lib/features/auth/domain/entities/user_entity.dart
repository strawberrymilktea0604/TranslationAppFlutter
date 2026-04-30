import 'package:equatable/equatable.dart';

/// Pure Dart entity representing a user.
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String role; // 'user' or 'admin'
  final DateTime createdAt;

  final String? avatarUrl;

  const UserEntity({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.role = 'user',
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, email, name, avatarUrl, role, createdAt];
}
