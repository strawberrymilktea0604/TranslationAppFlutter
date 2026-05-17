import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/features/learning/domain/entities/quiz_question_entity.dart';
import 'package:frontend/features/learning/domain/entities/quiz_result_entity.dart';
import 'package:frontend/features/learning/domain/usecases/get_quiz_questions_usecase.dart';
import 'package:frontend/features/learning/domain/usecases/submit_quiz_result_usecase.dart';
import 'quiz_state.dart';

/// Manages the Quiz Engine state and timer lifecycle.
///
/// Flow: UI → QuizCubit → UseCase → Repository → DataSource.
///
/// Key features:
/// 1. **Countdown Timer** using `Stream.periodic(Duration(seconds: 1))`
/// 2. **Auto-submit** when timer reaches 0
/// 3. **Interactive Feedback** via state changes (Xanh/Đỏ color, haptic)
///
/// Timer is managed via [StreamSubscription] and properly cancelled
/// in [close] to prevent memory leaks.
class QuizCubit extends Cubit<QuizState> {
  final GetQuizQuestionsUseCase _getQuizQuestionsUseCase;
  final SubmitQuizResultUseCase _submitQuizResultUseCase;

  QuizCubit({
    required GetQuizQuestionsUseCase getQuizQuestionsUseCase,
    required SubmitQuizResultUseCase submitQuizResultUseCase,
  })  : _getQuizQuestionsUseCase = getQuizQuestionsUseCase,
        _submitQuizResultUseCase = submitQuizResultUseCase,
        super(const QuizState());

  /// Active timer subscription — cancelled on submit or close.
  StreamSubscription<int>? _timerSubscription;

  // ────────────────────────────────────────────────────────────
  //  Quiz Lifecycle
  // ────────────────────────────────────────────────────────────

  /// Loads questions from the repository and starts the quiz.
  ///
  /// [bankId] identifies the question bank to load.
  /// [durationSeconds] sets the countdown timer duration.
  Future<void> loadAndStartQuiz({
    required String bankId,
    required int durationSeconds,
  }) async {
    emit(state.copyWith(
      status: QuizStatus.loading,
      bankId: bankId,
    ));

    final result = await _getQuizQuestionsUseCase(
      GetQuizQuestionsParams(bankId: bankId),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: QuizStatus.error,
        errorMessage: failure.message,
      )),
      (questions) {
        if (questions.isEmpty) {
          emit(state.copyWith(
            status: QuizStatus.error,
            errorMessage: 'Không tìm thấy câu hỏi trong bộ đề này.',
          ));
          return;
        }
        _startQuizWithQuestions(questions, durationSeconds);
      },
    );
  }

  /// Starts the quiz with provided questions (used when questions
  /// are already available, e.g. from local cache or passed directly).
  void startQuiz(List<QuizQuestionEntity> questions, int durationSeconds) {
    _startQuizWithQuestions(questions, durationSeconds);
  }

  /// Internal method to initialize quiz state and start the timer.
  void _startQuizWithQuestions(
    List<QuizQuestionEntity> questions,
    int durationSeconds,
  ) {
    emit(state.copyWith(
      questions: questions,
      remainingSeconds: durationSeconds,
      totalDurationSeconds: durationSeconds,
      status: QuizStatus.running,
      currentQuestionIndex: 0,
      selectedAnswers: const {},
      isAutoSubmitted: false,
    ));

    _startTimer();
  }

  /// Creates a countdown timer using Stream.periodic.
  ///
  /// Uses `Stream.periodic(Duration(seconds: 1))` as required.
  /// Each tick decrements [remainingSeconds] by 1.
  /// When reaching 0, automatically calls [submitQuiz] with
  /// the [isAutoSubmitted] flag set to true.
  void _startTimer() {
    _timerSubscription?.cancel();

    _timerSubscription = Stream.periodic(
      const Duration(seconds: 1),
      (tick) => tick,
    ).listen((_) {
      // Guard: only tick while quiz is running.
      if (state.status != QuizStatus.running) return;

      final newTime = state.remainingSeconds - 1;

      if (newTime <= 0) {
        // Timer expired — auto-submit.
        emit(state.copyWith(
          remainingSeconds: 0,
          isAutoSubmitted: true,
        ));
        submitQuiz();
      } else {
        emit(state.copyWith(remainingSeconds: newTime));
      }
    });
  }

  // ────────────────────────────────────────────────────────────
  //  User Interactions
  // ────────────────────────────────────────────────────────────

  /// Records the user's answer for a question.
  ///
  /// Ignores input if quiz is not running (already submitted)
  /// or if the question has already been answered.
  void selectAnswer(String questionId, String optionId) {
    if (state.status != QuizStatus.running) return;

    // Prevent changing answer after selection (immediate feedback mode).
    if (state.selectedAnswers.containsKey(questionId)) return;

    final newAnswers = Map<String, String>.from(state.selectedAnswers);
    newAnswers[questionId] = optionId;

    emit(state.copyWith(selectedAnswers: newAnswers));
  }

  /// Navigates to the next question.
  void nextQuestion() {
    if (state.currentQuestionIndex < state.questions.length - 1) {
      emit(state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
      ));
    }
  }

  /// Navigates to the previous question.
  void previousQuestion() {
    if (state.currentQuestionIndex > 0) {
      emit(state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex - 1,
      ));
    }
  }

  /// Jumps to a specific question by index.
  void goToQuestion(int index) {
    if (index >= 0 && index < state.questions.length) {
      emit(state.copyWith(currentQuestionIndex: index));
    }
  }

  // ────────────────────────────────────────────────────────────
  //  Quiz Submission
  // ────────────────────────────────────────────────────────────

  /// Submits the quiz results.
  ///
  /// Called either:
  /// - By user tapping the Submit button
  /// - Automatically when the countdown timer reaches 0
  ///
  /// Locks all interaction (via [QuizStatus.submitted])
  /// and sends results to the backend via [SubmitQuizResultUseCase].
  Future<void> submitQuiz() async {
    if (state.status == QuizStatus.submitted) return;

    // Stop the timer immediately.
    _timerSubscription?.cancel();

    // Calculate time taken.
    final timeTaken = state.totalDurationSeconds - state.remainingSeconds;

    // Build the result entity.
    final quizResult = QuizResultEntity(
      bankId: state.bankId,
      correctCount: state.correctCount,
      totalQuestions: state.questions.length,
      score: state.scorePercentage,
      timeTakenSeconds: timeTaken,
      selectedAnswers: state.selectedAnswers,
      isAutoSubmitted: state.isAutoSubmitted,
    );

    // Emit submitted state first to lock UI immediately.
    emit(state.copyWith(
      status: QuizStatus.submitted,
      result: quizResult,
    ));

    // Submit to backend (fire-and-forget style — result is
    // already shown to the user, backend sync can retry later).
    await _submitQuizResultUseCase(
      SubmitQuizResultParams(result: quizResult),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Cleanup
  // ────────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    _timerSubscription?.cancel();
    return super.close();
  }
}
