import 'package:equatable/equatable.dart';

/// UC07 — Entity for saved vocabulary words.
class VocabularyEntity extends Equatable {
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
