import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/learning/domain/entities/question_bank_entity.dart';
import 'package:frontend/features/learning/domain/repositories/learning_repository.dart';

/// Retrieves all available question banks (exam sets).
///
/// Returns a list of [QuestionBankEntity] sorted by most recently created.
/// Used by the Learning Dashboard to display the exam list.
class GetQuestionBanksUseCase
    extends UseCase<List<QuestionBankEntity>, NoParams> {
  final LearningRepository repository;

  GetQuestionBanksUseCase(this.repository);

  @override
  Future<Either<Failure, List<QuestionBankEntity>>> call(
    NoParams params,
  ) async {
    return await repository.getQuestionBanks();
  }
}
