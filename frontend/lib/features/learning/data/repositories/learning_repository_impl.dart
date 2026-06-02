import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/learning/data/datasources/quiz_remote_datasource.dart';
import 'package:frontend/features/learning/domain/entities/learning_summary_entity.dart';
import 'package:frontend/features/learning/domain/entities/question_bank_entity.dart';
import 'package:frontend/features/learning/domain/entities/recent_quiz_result_entity.dart';
import 'package:frontend/features/learning/domain/repositories/learning_repository.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_local_datasource.dart';
import 'package:frontend/features/vocabulary/data/models/question_bank_model.dart';

/// Offline-first implementation of [LearningRepository].
///
/// Reads all data from local Isar DB via [VocabularyLocalDataSource].
/// The learning feature reuses the vocabulary datasource because
/// question banks, quiz results, and vocabulary all reside in
/// the same Isar database.
class LearningRepositoryImpl implements LearningRepository {
  final VocabularyLocalDataSource _localDataSource;
  final QuizRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _authLocalDataSource;
  final NetworkInfo _networkInfo;

  LearningRepositoryImpl({
    required VocabularyLocalDataSource localDataSource,
    required QuizRemoteDataSource remoteDataSource,
    required AuthLocalDataSource authLocalDataSource,
    required NetworkInfo networkInfo,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _authLocalDataSource = authLocalDataSource,
       _networkInfo = networkInfo;

  @override
  Future<Either<Failure, LearningSummaryEntity>> getLearningSummary() async {
    try {
      // Fetch vocabulary summaries for word counts.
      final categorySummaries = await _localDataSource.getCategorySummaries();

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
          : quizResults.fold<double>(0.0, (sum, r) => sum + r.score) /
                quizzesCompleted;

      return Right(
        LearningSummaryEntity(
          totalWords: totalWords,
          learnedWords: learnedWords,
          quizzesCompleted: quizzesCompleted,
          averageScore: averageScore,
        ),
      );
    } catch (e) {
      return Left(CacheFailure('Failed to load learning summary: $e'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionBankEntity>>> getQuestionBanks() async {
    try {
      final token = await _authLocalDataSource.getAccessToken();
      final isConnected = await _networkInfo.isConnected;

      if (isConnected && token != null && token.isNotEmpty) {
        final remoteBanks = await _remoteDataSource.getQuestionBanks(
          token: token,
        );
        await _localDataSource.saveAllBanks(
          remoteBanks.map(_questionBankEntityToModel).toList(),
        );
        return Right(remoteBanks);
      }

      final models = await _localDataSource.getAllBanks();
      final entities = models.map(_questionBankModelToEntity).toList();
      return Right(entities);
    } catch (e) {
      try {
        final models = await _localDataSource.getAllBanks();
        final entities = models.map(_questionBankModelToEntity).toList();
        return Right(entities);
      } catch (_) {
        return Left(CacheFailure('Failed to load question banks: $e'));
      }
    }
  }

  @override
  Future<Either<Failure, List<RecentQuizResultEntity>>> getRecentQuizResults({
    int limit = 5,
  }) async {
    try {
      final models = await _localDataSource.getQuizResults(limit: limit);
      return Right(
        models
            .map(
              (model) => RecentQuizResultEntity(
                localId: model.id,
                backendId: model.backendId,
                bankId: model.bankBackendId,
                bankTitle: model.bankTitle,
                totalQuestions: model.totalQuestions,
                correctAnswers: model.correctAnswers,
                score: model.score,
                durationSeconds: model.durationSeconds,
                status: model.status,
                completedAt: model.completedAt,
                isSynced: model.isSynced,
              ),
            )
            .toList(),
      );
    } catch (e) {
      return Left(CacheFailure('Failed to load recent quiz results: $e'));
    }
  }

  QuestionBankEntity _questionBankModelToEntity(QuestionBankModel model) {
    return QuestionBankEntity(
      isarId: model.id,
      backendId: model.backendId,
      title: model.title,
      description: model.description,
      durationMinutes: model.durationMinutes,
      questionCount: model.questionCount,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    );
  }

  QuestionBankModel _questionBankEntityToModel(QuestionBankEntity entity) {
    return QuestionBankModel(
      backendId: entity.backendId,
      title: entity.title,
      description: entity.description,
      durationMinutes: entity.durationMinutes,
      questionCount: entity.questionCount,
      questions: const [],
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isSynced: true,
      isDeleted: false,
    );
  }
}
