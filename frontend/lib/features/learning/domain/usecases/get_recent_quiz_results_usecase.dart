import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/learning/domain/entities/recent_quiz_result_entity.dart';
import 'package:frontend/features/learning/domain/repositories/learning_repository.dart';

class GetRecentQuizResultsUseCase
    extends UseCase<List<RecentQuizResultEntity>, GetRecentQuizResultsParams> {
  final LearningRepository repository;

  GetRecentQuizResultsUseCase(this.repository);

  @override
  Future<Either<Failure, List<RecentQuizResultEntity>>> call(
    GetRecentQuizResultsParams params,
  ) async {
    return repository.getRecentQuizResults(limit: params.limit);
  }
}

class GetRecentQuizResultsParams extends Equatable {
  final int limit;

  const GetRecentQuizResultsParams({this.limit = 5});

  @override
  List<Object?> get props => [limit];
}
