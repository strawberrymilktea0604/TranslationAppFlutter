import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/learning/domain/entities/question_bank_entity.dart';
import 'package:frontend/features/learning/presentation/widgets/question_bank_card.dart';

void main() {
  group('QuestionBankCard', () {
    testWidgets('does not start quiz when bank has no questions', (tester) async {
      var startCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestionBankCard(
              bank: QuestionBankEntity(
                isarId: 0,
                backendId: 'empty-bank',
                title: 'Empty Bank',
                description: 'No questions yet',
                durationMinutes: 15,
                questionCount: 0,
                createdAt: DateTime(2026, 6, 3),
                updatedAt: DateTime(2026, 6, 3),
              ),
              onStart: () => startCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pump();

      expect(startCount, 0);
    });
  });
}
