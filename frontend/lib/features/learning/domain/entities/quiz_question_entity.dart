import 'package:equatable/equatable.dart';

class QuizOptionEntity extends Equatable {
  final String id;
  final String text;
  final bool isCorrect; // Added to evaluate answers during feedback

  const QuizOptionEntity({
    required this.id,
    required this.text,
    required this.isCorrect,
  });

  @override
  List<Object?> get props => [id, text, isCorrect];
}

class QuizQuestionEntity extends Equatable {
  final String id;
  final String content;
  final List<QuizOptionEntity> options;

  const QuizQuestionEntity({
    required this.id,
    required this.content,
    required this.options,
  });

  @override
  List<Object?> get props => [id, content, options];
}
