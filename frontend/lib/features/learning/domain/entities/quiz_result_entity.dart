import 'package:equatable/equatable.dart';

/// Domain entity representing the result of a completed quiz.
///
/// Contains the score, number of correct answers, total questions,
/// and the time taken. This is what gets submitted to the backend
/// after the user finishes (or auto-submits on timer expiry).
class QuizResultEntity extends Equatable {
  /// Server-side quiz attempt ID, or a local generated ID before sync.
  final String? backendId;

  /// The question bank ID this quiz belongs to.
  final String bankId;

  /// Number of correctly answered questions.
  final int correctCount;

  /// Total number of questions in the quiz.
  final int totalQuestions;

  /// Calculated score as percentage (0.0 – 100.0).
  final double score;

  /// Duration in seconds the user actually spent on the quiz.
  final int timeTakenSeconds;

  /// Map of questionId → selected optionId.
  final Map<String, String> selectedAnswers;

  /// Whether the quiz was auto-submitted due to timer expiry.
  final bool isAutoSubmitted;

  /// Backend/local status for the attempt.
  final String status;

  /// Completion timestamp.
  final DateTime? completedAt;

  const QuizResultEntity({
    this.backendId,
    required this.bankId,
    required this.correctCount,
    required this.totalQuestions,
    required this.score,
    required this.timeTakenSeconds,
    required this.selectedAnswers,
    this.isAutoSubmitted = false,
    this.status = 'completed',
    this.completedAt,
  });

  @override
  List<Object?> get props => [
    backendId,
    bankId,
    correctCount,
    totalQuestions,
    score,
    timeTakenSeconds,
    selectedAnswers,
    isAutoSubmitted,
    status,
    completedAt,
  ];
}
