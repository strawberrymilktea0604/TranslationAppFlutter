import 'package:equatable/equatable.dart';

/// Pure Dart entity representing a user.
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String role; // 'user' or 'admin'
  final String status; // 'active' or 'locked'
  final DateTime createdAt;

  final String? avatarUrl;

  const UserEntity({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.role = 'user',
    this.status = 'active',
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, email, name, avatarUrl, role, status, createdAt];
}
