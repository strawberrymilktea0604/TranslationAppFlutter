import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/learning/domain/entities/quiz_result_entity.dart';
import 'package:frontend/features/learning/domain/repositories/quiz_repository.dart';

/// Submits quiz results to the backend.
///
/// Called either:
/// - When the user taps "Submit" manually
/// - When the countdown timer reaches 0 (auto-submit)
///
/// The repository implementation handles offline caching
/// if the network is unavailable.
class SubmitQuizResultUseCase
    extends UseCase<QuizResultEntity, SubmitQuizResultParams> {
  final QuizRepository repository;

  SubmitQuizResultUseCase(this.repository);

  @override
  Future<Either<Failure, QuizResultEntity>> call(
    SubmitQuizResultParams params,
  ) async {
    return await repository.submitResult(result: params.result);
  }
}

/// Parameters for [SubmitQuizResultUseCase].
class SubmitQuizResultParams extends Equatable {
  final QuizResultEntity result;

  const SubmitQuizResultParams({required this.result});

  @override
  List<Object?> get props => [result];
}
