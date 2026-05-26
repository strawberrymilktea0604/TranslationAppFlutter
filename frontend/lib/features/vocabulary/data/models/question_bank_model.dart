import 'package:isar_community/isar.dart';

part 'question_bank_model.g.dart';

/// Isar collection mirroring the backend `question_banks` + `questions` tables.
///
/// Each bank contains a list of embedded [QuestionItem] objects.
/// The `isSynced` flag indicates whether this bank's data matches the server.
@collection
class QuestionBankModel {
  Id id = Isar.autoIncrement;

  /// Server-side ID.
  @Index(unique: true, replace: true)
  late String backendId;

  late String title;
  String? description;

  /// Time limit in minutes (null = no limit).
  int? durationMinutes;

  /// Number of questions in this bank.
  late int questionCount;

  /// Embedded list of questions.
  late List<QuestionItem> questions;

  @Index()
  late DateTime createdAt;
  late DateTime updatedAt;

  /// Whether this data is in sync with the server.
  late bool isSynced;
  late bool isDeleted;

  QuestionBankModel({
    required this.backendId,
    required this.title,
    this.description,
    this.durationMinutes,
    this.questionCount = 0,
    this.questions = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
  });

  QuestionBankModel.isar();

  factory QuestionBankModel.fromJson(Map<String, dynamic> json) {
    final questionList =
        (json['questions'] as List<dynamic>?)
            ?.map((q) => QuestionItem.fromJson(q as Map<String, dynamic>))
            .toList() ??
        [];

    return QuestionBankModel(
      backendId: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      questionCount: questionList.length,
      questions: questionList,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      isSynced: true,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': backendId,
      'title': title,
      'description': description,
      'duration_minutes': durationMinutes,
      'questions': questions.map((q) => q.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }
}

/// Embedded object representing a single question within a [QuestionBankModel].
///
/// Isar stores this inline — no separate collection needed.
@embedded
class QuestionItem {
  /// Server-side question ID.
  late String questionBackendId;

  /// Question text (e.g. "What is the Vietnamese of 'drizzle'?").
  late String content;

  /// The correct answer.
  late String correctAnswer;

  /// Wrong answer options (typically 3).
  late List<String> choices;

  /// Whether this question has been soft-deleted on the server.
  late bool isDeleted;

  QuestionItem({
    this.questionBackendId = '',
    this.content = '',
    this.correctAnswer = '',
    this.choices = const [],
    this.isDeleted = false,
  });

  QuestionItem.empty()
    : questionBackendId = '',
      content = '',
      correctAnswer = '',
      choices = [],
      isDeleted = false;

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    // Backend sends choices as JSONB — could be List<String> or List<dynamic>
    final rawChoices = json['choices'];
    List<String> parsedChoices = [];
    if (rawChoices is List) {
      parsedChoices = rawChoices.map((e) => e.toString()).toList();
    }

    return QuestionItem(
      questionBackendId: json['id'].toString(),
      content: json['content'] as String? ?? '',
      correctAnswer: json['correct_answer'] as String? ?? '',
      choices: parsedChoices,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': questionBackendId,
      'content': content,
      'correct_answer': correctAnswer,
      'choices': choices,
      'is_deleted': isDeleted,
    };
  }
}
