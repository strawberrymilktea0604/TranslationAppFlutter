import 'package:isar_community/isar.dart';

part 'quiz_result_model.g.dart';

/// Isar collection storing quiz results (maps to backend `user_quizzes` table).
///
/// Created after the user completes a quiz from a [QuestionBankModel].
/// The `isSynced` flag starts as `false` — the sync service will
/// upload unsynced results when network is available.
@collection
class QuizResultModel {
  Id id = Isar.autoIncrement;

  /// Server-side UserQuiz ID (empty until synced).
  @Index(unique: true, replace: true)
  late String backendId;

  /// Server-side QuestionBank ID that was answered.
  @Index()
  late String bankBackendId;

  /// Title of the question bank (denormalized for offline display).
  late String bankTitle;

  /// Total number of questions in the quiz.
  late int totalQuestions;

  /// Number of correct answers.
  late int correctAnswers;

  /// Percentage score (0.0 – 100.0).
  late double score;

  /// Time taken to complete the quiz in seconds.
  late int durationSeconds;

  /// 'completed' or 'timeout'.
  late String status;

  /// Per-question breakdown stored as embedded objects.
  late List<QuizAnswerItem> answers;

  @Index()
  late DateTime completedAt;

  /// Whether this result has been uploaded to the server.
  /// Starts as `false` for locally-completed quizzes.
  late bool isSynced;

  QuizResultModel({
    required this.backendId,
    required this.bankBackendId,
    required this.bankTitle,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.score,
    required this.durationSeconds,
    required this.status,
    this.answers = const [],
    required this.completedAt,
    this.isSynced = false,
  });

  QuizResultModel.isar();

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
    final answerList = (json['results'] as List<dynamic>?)
        ?.map((a) => QuizAnswerItem.fromJson(a as Map<String, dynamic>))
        .toList() ?? [];

    return QuizResultModel(
      backendId: json['quiz_id'].toString(),
      bankBackendId: json['bank_id'].toString(),
      bankTitle: json['bank_title'] as String? ?? '',
      totalQuestions: json['total_questions'] as int? ?? 0,
      correctAnswers: json['correct_count'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: json['completion_time_seconds'] as int? ?? 0,
      status: json['status'] as String? ?? 'completed',
      answers: answerList,
      completedAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isSynced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': backendId,
      'bank_id': bankBackendId,
      'bank_title': bankTitle,
      'total_questions': totalQuestions,
      'correct_count': correctAnswers,
      'score': score,
      'completion_time_seconds': durationSeconds,
      'status': status,
      'results': answers.map((a) => a.toJson()).toList(),
      'created_at': completedAt.toIso8601String(),
    };
  }
}

/// Embedded object: one answer in a quiz attempt.
@embedded
class QuizAnswerItem {
  late String questionBackendId;
  late String selectedAnswer;
  late String correctAnswer;
  late bool isCorrect;

  QuizAnswerItem({
    this.questionBackendId = '',
    this.selectedAnswer = '',
    this.correctAnswer = '',
    this.isCorrect = false,
  });

  QuizAnswerItem.empty()
      : questionBackendId = '',
        selectedAnswer = '',
        correctAnswer = '',
        isCorrect = false;

  factory QuizAnswerItem.fromJson(Map<String, dynamic> json) {
    return QuizAnswerItem(
      questionBackendId: json['question_id'].toString(),
      selectedAnswer: json['selected_answer'] as String? ?? '',
      correctAnswer: json['correct_answer'] as String? ?? '',
      isCorrect: json['is_correct'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionBackendId,
      'selected_answer': selectedAnswer,
      'correct_answer': correctAnswer,
      'is_correct': isCorrect,
    };
  }
}
