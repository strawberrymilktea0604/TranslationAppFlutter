import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/learning/domain/entities/learning_summary_entity.dart';
import 'package:frontend/features/learning/domain/entities/question_bank_entity.dart';

/// Abstract repository for the Learning Dashboard feature.
///
/// Provides read-only access to:
/// - Learning summary (vocabulary + quiz stats)
/// - Available question banks (exam sets)
///
/// Data is read from local Isar DB first (offline-first).
abstract class LearningRepository {
  /// Get aggregated learning summary (total words, learned,
  /// quizzes completed, average score).
  Future<Either<Failure, LearningSummaryEntity>> getLearningSummary();

  /// Get all available question banks.
  Future<Either<Failure, List<QuestionBankEntity>>> getQuestionBanks();
}
