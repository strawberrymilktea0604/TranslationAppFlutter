import 'package:equatable/equatable.dart';

/// UC07 — Entity for saved vocabulary words.
class VocabularyEntity extends Equatable {
  /// Isar auto-increment primary key (local DB).
  /// Used for local delete/update operations.
  final int isarId;

  /// Backend UUID assigned after sync.
  /// For local-only entries, this is a temporary
  /// `local_<timestamp>` value.
  final String id;

  final String word;
  final String translation;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;

  const VocabularyEntity({
    required this.isarId,
    required this.id,
    required this.word,
    required this.translation,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
  });

  @override
  List<Object?> get props => [
    isarId,
    id,
    word,
    translation,
    sourceLanguage,
    targetLanguage,
    createdAt,
    updatedAt,
    isSynced,
    isDeleted,
  ];
}
