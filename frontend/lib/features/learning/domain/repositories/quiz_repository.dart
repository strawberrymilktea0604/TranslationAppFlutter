import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/learning/domain/entities/quiz_question_entity.dart';
import 'package:frontend/features/learning/domain/entities/quiz_result_entity.dart';

/// Abstract repository for the Quiz Engine feature.
///
/// Provides:
/// - Fetching quiz questions for a given question bank
/// - Submitting quiz results to the backend
///
/// The implementation handles offline-first logic:
/// questions are read from Isar, results are submitted
/// to the backend when online and cached locally when offline.
abstract class QuizRepository {
  /// Fetch all questions for a specific question bank.
  ///
  /// [bankId] is the backend ID of the question bank.
  Future<Either<Failure, List<QuizQuestionEntity>>> getQuestions({
    required String bankId,
  });

  /// Submit quiz results to the backend.
  ///
  /// Returns the [QuizResultEntity] with any server-side
  /// enrichment (e.g., updated score, rank).
  Future<Either<Failure, QuizResultEntity>> submitResult({
    required QuizResultEntity result,
  });
}
