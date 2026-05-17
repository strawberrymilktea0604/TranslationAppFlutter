import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/learning/domain/entities/learning_summary_entity.dart';
import 'package:frontend/features/learning/domain/entities/question_bank_entity.dart';
import 'package:frontend/features/learning/domain/repositories/learning_repository.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_local_datasource.dart';

/// Offline-first implementation of [LearningRepository].
///
/// Reads all data from local Isar DB via [VocabularyLocalDataSource].
/// The learning feature reuses the vocabulary datasource because
/// question banks, quiz results, and vocabulary all reside in
/// the same Isar database.
class LearningRepositoryImpl implements LearningRepository {
  final VocabularyLocalDataSource _localDataSource;

  LearningRepositoryImpl({
    required VocabularyLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  @override
  Future<Either<Failure, LearningSummaryEntity>> getLearningSummary() async {
    try {
      // Fetch vocabulary summaries for word counts.
      final categorySummaries =
          await _localDataSource.getCategorySummaries();

      final totalWords = categorySummaries.fold<int>(
        0,
        (sum, cat) => sum + cat.wordCount,
      );
      final learnedWords = categorySummaries.fold<int>(
        0,
        (sum, cat) => sum + cat.learnedCount,
      );

      // Fetch quiz results for quiz stats.
      final quizResults = await _localDataSource.getQuizResults();
      final quizzesCompleted = quizResults.length;
      final averageScore = quizzesCompleted == 0
          ? 0.0
          : quizResults.fold<double>(
                0.0,
                (sum, r) => sum + r.score,
              ) /
              quizzesCompleted;

      return Right(LearningSummaryEntity(
        totalWords: totalWords,
        learnedWords: learnedWords,
        quizzesCompleted: quizzesCompleted,
        averageScore: averageScore,
      ));
    } catch (e) {
      return Left(CacheFailure('Failed to load learning summary: $e'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionBankEntity>>> getQuestionBanks() async {
    try {
      final models = await _localDataSource.getAllBanks();
      final entities = models
          .map((m) => QuestionBankEntity(
                isarId: m.id,
                backendId: m.backendId,
                title: m.title,
                description: m.description,
                durationMinutes: m.durationMinutes,
                questionCount: m.questionCount,
                createdAt: m.createdAt,
                updatedAt: m.updatedAt,
              ))
          .toList();
      return Right(entities);
    } catch (e) {
      return Left(CacheFailure('Failed to load question banks: $e'));
    }
  }
}
