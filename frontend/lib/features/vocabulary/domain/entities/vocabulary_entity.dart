import 'package:equatable/equatable.dart';

/// UC07 — Entity for saved vocabulary words.
class VocabularyEntity extends Equatable {
  /// Isar local auto-increment ID. Used for soft-delete operations.
  /// 0 means not yet persisted (transient).
  final int isarId;

  /// Backend UUID (or temp "local_xxx" ID before sync).
  final String id;
  final String word;
  final String translation;
  final String sourceLanguage;
  final String targetLanguage;

  /// Category for flashcard grouping (e.g. "Weather", "Medical Health").
  final String category;

  /// Whether the user has starred/favorited this word.
  final bool isStarred;

  /// Optional IPA pronunciation.
  final String? pronunciation;

  /// Optional example sentence.
  final String? example;

  /// Backend translation record ID (for sync).
  final int? translationId;

  /// Mastery level (0–5) for spaced-repetition.
  final int masteryLevel;

  /// When this word was last reviewed/tested.
  final DateTime? lastTestedAt;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;

  const VocabularyEntity({
    required this.id,
    required this.word,
    required this.translation,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.createdAt,
    required this.updatedAt,
    this.isarId = 0,
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

  @override
  List<Object?> get props => [
    isarId,
    id,
    word,
    translation,
    sourceLanguage,
    targetLanguage,
    category,
    isStarred,
    pronunciation,
    example,
    translationId,
    masteryLevel,
    lastTestedAt,
    createdAt,
    updatedAt,
    isSynced,
    isDeleted,
  ];
}
