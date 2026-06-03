import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/learning/data/datasources/quiz_remote_datasource.dart';
import 'package:frontend/features/learning/domain/entities/quiz_result_entity.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('QuizRemoteDataSourceImpl', () {
    test('maps object choices into quiz options', () async {
      final dataSource = QuizRemoteDataSourceImpl(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/learning/banks/7/start');
          return http.Response(
            jsonEncode({
              'id': 7,
              'title': 'Practice',
              'total_questions': 1,
              'questions': [
                {
                  'id': 12,
                  'content':
                      'Someone has leaked ________ government information to the press.',
                  'choices': {
                    'A': 'confidential',
                    'B': 'confident',
                    'C': 'confidence',
                    'D': 'confide',
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUrl: 'http://localhost:8000/api/v1',
      );

      final questions = await dataSource.getQuestions(
        bankId: '7',
        token: 'token',
      );

      expect(questions, hasLength(1));
      expect(questions.single.options, hasLength(4));
      expect(questions.single.options.first.id, 'A');
      expect(questions.single.options.first.text, 'confidential');
    });

    test('submits empty answers when user submits and exits without choices', () async {
      late Map<String, dynamic> requestBody;
      final dataSource = QuizRemoteDataSourceImpl(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/learning/banks/7/submit');
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'quiz_id': 99,
              'bank_id': 7,
              'score': 0,
              'total_questions': 5,
              'correct_answers': 0,
              'time_spent_seconds': 12,
              'status': 'completed',
              'submitted_at': '2026-06-03T15:42:00Z',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUrl: 'http://localhost:8000/api/v1',
      );

      final submitted = await dataSource.submitResult(
        result: QuizResultEntity(
          bankId: '7',
          correctCount: 0,
          totalQuestions: 5,
          score: 0,
          timeTakenSeconds: 12,
          selectedAnswers: const {},
        ),
        token: 'token',
      );

      expect(requestBody['answers'], isEmpty);
      expect(requestBody['time_spent_seconds'], 12);
      expect(submitted.backendId, '99');
      expect(submitted.correctCount, 0);
      expect(submitted.totalQuestions, 5);
    });
  });
}
