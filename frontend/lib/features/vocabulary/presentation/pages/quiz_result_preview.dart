import 'package:flutter/material.dart';

import 'package:frontend/features/vocabulary/presentation/pages/quiz_result_page.dart';

/// Temporary preview page to visually test [QuizResultPage].
/// Remove this file after integrating with real quiz flow.
///
/// Usage in main.dart or routes:
/// ```dart
/// MaterialPageRoute(builder: (_) => const QuizResultPreview()),
/// ```
class QuizResultPreview extends StatelessWidget {
  const QuizResultPreview({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data that mirrors the wireframe reference:
    // 28/30 correct, 93%, time 04:30 / 05:00
    const sampleData = QuizResultData(
      title: 'Bài kiểm tra Từ vựng N3',
      totalQuestions: 30,
      correctAnswers: 28,
      score: 93.3,
      durationSeconds: 270, // 04:30
      timeLimitSeconds: 300, // 05:00
      wrongAnswers: [
        QuizWrongAnswer(
          questionText: '"Appreciate" nghĩa là gì?',
          userAnswer: 'Phê bình',
          correctAnswer: 'Đánh giá cao / Trân trọng',
        ),
        QuizWrongAnswer(
          questionText: '"Ubiquitous" nghĩa là gì?',
          userAnswer: 'Hiếm có',
          correctAnswer: 'Có mặt ở khắp nơi',
        ),
      ],
    );

    return QuizResultPage(
      data: sampleData,
      onRetry: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Làm lại bài kiểm tra...')),
        );
      },
      onGoHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
    );
  }
}
