import 'package:equatable/equatable.dart';

/// UC08 — Entity for translation history records.
class HistoryEntity extends Equatable {
  /// Isar local auto-increment ID. Used for soft-delete operations.
  final int isarId;

  final String id;
  final String sourceText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;

  const HistoryEntity({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
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
    sourceText,
    translatedText,
    sourceLanguage,
    targetLanguage,
    createdAt,
    updatedAt,
    isSynced,
    isDeleted,
  ];
}
