import 'package:equatable/equatable.dart';

/// Domain entity representing a question bank (exam set).
///
/// Pure Dart class — no framework dependency.
/// Contains overview info displayed on the Learning Dashboard
/// before the user starts a quiz.
class QuestionBankEntity extends Equatable {
  /// Isar auto-increment ID.
  final int isarId;

  /// Server-side ID for sync.
  final String backendId;

  /// Display title (e.g. "Từ vựng Thời tiết").
  final String title;

  /// Optional description.
  final String? description;

  /// Time limit in minutes (null = no limit).
  final int? durationMinutes;

  /// Total number of questions in this bank.
  final int questionCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  const QuestionBankEntity({
    required this.isarId,
    required this.backendId,
    required this.title,
    this.description,
    this.durationMinutes,
    required this.questionCount,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        isarId,
        backendId,
        title,
        description,
        durationMinutes,
        questionCount,
        createdAt,
        updatedAt,
      ];
}
