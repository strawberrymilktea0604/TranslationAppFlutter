import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/learning/data/datasources/quiz_remote_datasource.dart';
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
  });
}
