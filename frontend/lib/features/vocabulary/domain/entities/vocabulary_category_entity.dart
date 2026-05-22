import 'package:equatable/equatable.dart';

class VocabularyCategoryEntity extends Equatable {
  final int isarId;
  final int id; // Backend ID
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;

  const VocabularyCategoryEntity({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.isarId = 0,
    this.isSynced = false,
    this.isDeleted = false,
  });

  @override
  List<Object?> get props => [
    isarId,
    id,
    name,
    createdAt,
    updatedAt,
    isSynced,
    isDeleted,
  ];
}
