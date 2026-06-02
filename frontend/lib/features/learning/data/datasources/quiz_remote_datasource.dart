import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:frontend/features/learning/domain/entities/question_bank_entity.dart';
import 'package:frontend/features/learning/domain/entities/quiz_question_entity.dart';
import 'package:frontend/features/learning/domain/entities/quiz_result_entity.dart';

/// Remote data source for Quiz operations.
///
/// Communicates with the backend API:
/// - `GET  /api/v1/quiz/{bankId}/questions` — fetch questions
/// - `POST /api/v1/quiz/submit`             — submit results
abstract class QuizRemoteDataSource {
  /// Fetch active question banks from the backend.
  Future<List<QuestionBankEntity>> getQuestionBanks({required String token});

  /// Fetch all questions for a given question bank from the backend.
  Future<List<QuizQuestionEntity>> getQuestions({
    required String bankId,
    required String token,
  });

  /// Submit quiz results to the backend.
  Future<QuizResultEntity> submitResult({
    required QuizResultEntity result,
    required String token,
  });
}

/// Implementation of [QuizRemoteDataSource] using [http.Client].
class QuizRemoteDataSourceImpl implements QuizRemoteDataSource {
  final http.Client _client;
  final String _baseUrl;

  QuizRemoteDataSourceImpl({
    required http.Client client,
    required String baseUrl,
  }) : _client = client,
       _baseUrl = baseUrl;

  @override
  Future<List<QuestionBankEntity>> getQuestionBanks({
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/learning/banks');
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch question banks: ${response.statusCode} ${response.body}',
      );
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((json) => _mapQuestionBank(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<QuizQuestionEntity>> getQuestions({
    required String bankId,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/learning/banks/$bankId/start');
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch questions: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final questions = data['questions'] as List<dynamic>? ?? [];
    return questions
        .map((json) => _mapQuestion(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<QuizResultEntity> submitResult({
    required QuizResultEntity result,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/learning/banks/${result.bankId}/submit');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'time_spent_seconds': result.timeTakenSeconds,
        'answers': result.selectedAnswers.entries
            .map(
              (entry) => {
                'question_id': int.tryParse(entry.key) ?? entry.key,
                'selected_answer': entry.value,
              },
            )
            .toList(),
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Failed to submit quiz: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return QuizResultEntity(
      backendId: data['quiz_id']?.toString(),
      bankId: (data['bank_id'] ?? result.bankId).toString(),
      correctCount:
          data['correct_count'] as int? ??
          data['correct_answers'] as int? ??
          result.correctCount,
      totalQuestions: data['total_questions'] as int? ?? result.totalQuestions,
      score: (data['score'] as num?)?.toDouble() ?? result.score,
      timeTakenSeconds:
          data['time_spent_seconds'] as int? ??
          data['completion_time_seconds'] as int? ??
          result.timeTakenSeconds,
      selectedAnswers: result.selectedAnswers,
      isAutoSubmitted: result.isAutoSubmitted,
      status: data['status'] as String? ?? result.status,
      completedAt:
          _parseDate(data['submitted_at']) ??
          _parseDate(data['created_at']) ??
          result.completedAt,
    );
  }

  /// Maps a JSON map to [QuestionBankEntity].
  QuestionBankEntity _mapQuestionBank(Map<String, dynamic> json) {
    final createdAt = _parseDate(json['created_at']) ?? DateTime.now();
    final updatedAt = _parseDate(json['updated_at']) ?? createdAt;

    return QuestionBankEntity(
      isarId: 0,
      backendId: json['id'].toString(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      questionCount: json['question_count'] as int? ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Maps a JSON map to [QuizQuestionEntity].
  QuizQuestionEntity _mapQuestion(Map<String, dynamic> json) {
    final options = _mapOptions(json);

    return QuizQuestionEntity(
      id: json['id'].toString(),
      content: json['content'] as String? ?? '',
      options: options,
    );
  }

  List<QuizOptionEntity> _mapOptions(Map<String, dynamic> json) {
    final rawOptions = json['options'] ?? json['choices'];
    if (rawOptions is List) {
      return rawOptions.asMap().entries.map((entry) {
        final raw = entry.value;
        if (raw is Map<String, dynamic>) {
          return QuizOptionEntity(
            id:
                raw['id']?.toString() ??
                raw['text']?.toString() ??
                '${entry.key}',
            text: raw['text']?.toString() ?? raw['label']?.toString() ?? '',
            isCorrect: raw['is_correct'] as bool? ?? false,
          );
        }
        return QuizOptionEntity(
          id: raw.toString(),
          text: raw.toString(),
          isCorrect: false,
        );
      }).toList();
    }
    if (rawOptions is Map) {
      return rawOptions.entries.map((entry) {
        final key = entry.key.toString();
        final raw = entry.value;
        if (raw is Map<String, dynamic>) {
          return QuizOptionEntity(
            id: raw['id']?.toString() ?? key,
            text: raw['text']?.toString() ?? raw['label']?.toString() ?? '',
            isCorrect: raw['is_correct'] as bool? ?? false,
          );
        }
        return QuizOptionEntity(
          id: key,
          text: raw.toString(),
          isCorrect: false,
        );
      }).toList();
    }
    return const [];
  }

  DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
