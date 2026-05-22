import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:frontend/features/learning/domain/entities/quiz_question_entity.dart';
import 'package:frontend/features/learning/domain/entities/quiz_result_entity.dart';

/// Remote data source for Quiz operations.
///
/// Communicates with the backend API:
/// - `GET  /api/v1/quiz/{bankId}/questions` — fetch questions
/// - `POST /api/v1/quiz/submit`             — submit results
abstract class QuizRemoteDataSource {
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
  })  : _client = client,
        _baseUrl = baseUrl;

  @override
  Future<List<QuizQuestionEntity>> getQuestions({
    required String bankId,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/quiz/$bankId/questions');
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

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((json) => _mapQuestion(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<QuizResultEntity> submitResult({
    required QuizResultEntity result,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/quiz/submit');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'bank_id': result.bankId,
        'correct_count': result.correctCount,
        'total_questions': result.totalQuestions,
        'score': result.score,
        'time_taken_seconds': result.timeTakenSeconds,
        'selected_answers': result.selectedAnswers,
        'is_auto_submitted': result.isAutoSubmitted,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Failed to submit quiz: ${response.statusCode} ${response.body}',
      );
    }

    // Return the original result (server may enrich in future).
    return result;
  }

  /// Maps a JSON map to [QuizQuestionEntity].
  QuizQuestionEntity _mapQuestion(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>)
        .map((o) => QuizOptionEntity(
              id: o['id'] as String,
              text: o['text'] as String,
              isCorrect: o['is_correct'] as bool,
            ))
        .toList();

    return QuizQuestionEntity(
      id: json['id'] as String,
      content: json['content'] as String,
      options: options,
    );
  }
}
