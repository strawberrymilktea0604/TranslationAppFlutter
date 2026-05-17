import 'package:equatable/equatable.dart';

/// Domain entity summarizing the user's learning progress.
///
/// Used on the Learning Dashboard header to display
/// overall vocabulary and quiz statistics at a glance.
class LearningSummaryEntity extends Equatable {
  /// Total number of saved vocabulary words.
  final int totalWords;

  /// Words considered "learned" (masteryLevel >= 3).
  final int learnedWords;

  /// Total number of quizzes completed.
  final int quizzesCompleted;

  /// Average score across all completed quizzes (0.0 – 100.0).
  final double averageScore;

  /// Overall vocabulary progress percentage (0.0 – 100.0).
  double get vocabularyProgress =>
      totalWords == 0 ? 0.0 : (learnedWords / totalWords * 100);

  const LearningSummaryEntity({
    required this.totalWords,
    required this.learnedWords,
    required this.quizzesCompleted,
    required this.averageScore,
  });

  @override
  List<Object?> get props => [
        totalWords,
        learnedWords,
        quizzesCompleted,
        averageScore,
      ];
}
