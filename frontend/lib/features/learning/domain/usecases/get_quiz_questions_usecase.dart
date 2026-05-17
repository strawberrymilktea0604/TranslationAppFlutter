import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/learning/domain/entities/quiz_question_entity.dart';
import 'package:frontend/features/learning/domain/repositories/quiz_repository.dart';

/// Retrieves all questions for a specific question bank.
///
/// Used by [QuizCubit] to load questions before starting the quiz.
class GetQuizQuestionsUseCase
    extends UseCase<List<QuizQuestionEntity>, GetQuizQuestionsParams> {
  final QuizRepository repository;

  GetQuizQuestionsUseCase(this.repository);

  @override
  Future<Either<Failure, List<QuizQuestionEntity>>> call(
    GetQuizQuestionsParams params,
  ) async {
    return await repository.getQuestions(bankId: params.bankId);
  }
}

/// Parameters for [GetQuizQuestionsUseCase].
class GetQuizQuestionsParams extends Equatable {
  final String bankId;

  const GetQuizQuestionsParams({required this.bankId});

  @override
  List<Object?> get props => [bankId];
}
