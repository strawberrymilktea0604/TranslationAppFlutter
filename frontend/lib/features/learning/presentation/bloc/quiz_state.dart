import 'package:equatable/equatable.dart';

import 'package:frontend/features/learning/domain/entities/quiz_question_entity.dart';
import 'package:frontend/features/learning/domain/entities/quiz_result_entity.dart';

/// Possible states of the quiz lifecycle.
enum QuizStatus {
  /// Initial state before quiz data is loaded.
  initial,

  /// Questions are being fetched from repository.
  loading,

  /// Quiz is active and the timer is counting down.
  running,

  /// Quiz has been submitted (manually or auto).
  submitted,

  /// An error occurred during loading or submission.
  error,
}

/// Immutable state for the Quiz Engine.
///
/// Managed by [QuizCubit]. Uses [Equatable] for efficient
/// BlocBuilder rebuilds — only changed fields trigger UI updates.
class QuizState extends Equatable {
  /// All questions in the current quiz.
  final List<QuizQuestionEntity> questions;

  /// Index of the currently displayed question.
  final int currentQuestionIndex;

  /// Remaining seconds on the countdown timer.
  final int remainingSeconds;

  /// Total duration of the quiz in seconds (for calculating time taken).
  final int totalDurationSeconds;

  /// Map of questionId → selected optionId.
  final Map<String, String> selectedAnswers;

  /// Current quiz lifecycle status.
  final QuizStatus status;

  /// The question bank ID this quiz belongs to.
  final String bankId;

  /// The quiz result after submission.
  final QuizResultEntity? result;

  /// Error message if status is [QuizStatus.error].
  final String? errorMessage;

  /// Whether the quiz was auto-submitted due to timer expiry.
  final bool isAutoSubmitted;

  const QuizState({
    this.questions = const [],
    this.currentQuestionIndex = 0,
    this.remainingSeconds = 0,
    this.totalDurationSeconds = 0,
    this.selectedAnswers = const {},
    this.status = QuizStatus.initial,
    this.bankId = '',
    this.result,
    this.errorMessage,
    this.isAutoSubmitted = false,
  });

  /// Whether the timer is in the warning zone (< 60 seconds).
  bool get isWarningTime =>
      remainingSeconds < 60 &&
      remainingSeconds > 0 &&
      status == QuizStatus.running;

  /// Whether the timer is in the critical zone (< 10 seconds).
  bool get isCriticalTime =>
      remainingSeconds <= 10 &&
      remainingSeconds > 0 &&
      status == QuizStatus.running;

  /// Number of questions the user has answered.
  int get answeredCount => selectedAnswers.length;

  /// Progress percentage (0.0 – 1.0).
  double get progress =>
      questions.isEmpty ? 0.0 : answeredCount / questions.length;

  /// Calculate the number of correct answers.
  int get correctCount {
    int count = 0;
    for (final question in questions) {
      final selectedOptionId = selectedAnswers[question.id];
      if (selectedOptionId != null) {
        final selectedOption = question.options.firstWhere(
          (o) => o.id == selectedOptionId,
          orElse: () => const QuizOptionEntity(
            id: '',
            text: '',
            isCorrect: false,
          ),
        );
        if (selectedOption.isCorrect) count++;
      }
    }
    return count;
  }

  /// Calculated score as percentage.
  double get scorePercentage =>
      questions.isEmpty ? 0.0 : (correctCount / questions.length) * 100;

  QuizState copyWith({
    List<QuizQuestionEntity>? questions,
    int? currentQuestionIndex,
    int? remainingSeconds,
    int? totalDurationSeconds,
    Map<String, String>? selectedAnswers,
    QuizStatus? status,
    String? bankId,
    QuizResultEntity? result,
    String? errorMessage,
    bool? isAutoSubmitted,
  }) {
    return QuizState(
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      status: status ?? this.status,
      bankId: bankId ?? this.bankId,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isAutoSubmitted: isAutoSubmitted ?? this.isAutoSubmitted,
    );
  }

  @override
  List<Object?> get props => [
        questions,
        currentQuestionIndex,
        remainingSeconds,
        totalDurationSeconds,
        selectedAnswers,
        status,
        bankId,
        result,
        errorMessage,
        isAutoSubmitted,
      ];
}
