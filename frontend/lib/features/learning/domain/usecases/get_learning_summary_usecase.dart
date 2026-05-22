import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/learning/domain/entities/learning_summary_entity.dart';
import 'package:frontend/features/learning/domain/repositories/learning_repository.dart';

/// Retrieves the aggregated learning summary for the dashboard.
///
/// Returns [LearningSummaryEntity] containing total words, learned words,
/// quizzes completed, and average score.
class GetLearningSummaryUseCase
    extends UseCase<LearningSummaryEntity, NoParams> {
  final LearningRepository repository;

  GetLearningSummaryUseCase(this.repository);

  @override
  Future<Either<Failure, LearningSummaryEntity>> call(
    NoParams params,
  ) async {
    return await repository.getLearningSummary();
  }
}
