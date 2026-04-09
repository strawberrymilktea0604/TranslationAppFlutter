import 'package:equatable/equatable.dart';

/// Pure Dart entity representing a translation result.
/// No framework dependency — belongs to the Domain layer.
class TranslationEntity extends Equatable {
  final String id;
  final String sourceText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;

  const TranslationEntity({
    required this.id,
    required this.sourceText,
    required this.translatedText,
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
