import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/learning/data/datasources/quiz_remote_datasource.dart';
import 'package:frontend/features/learning/domain/entities/quiz_question_entity.dart';
import 'package:frontend/features/learning/domain/entities/quiz_result_entity.dart';
import 'package:frontend/features/learning/domain/repositories/quiz_repository.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_local_datasource.dart';
import 'package:frontend/features/vocabulary/data/models/quiz_result_model.dart';

/// Implementation of [QuizRepository].
class QuizRepositoryImpl implements QuizRepository {
  final QuizRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _authLocalDataSource;
  final NetworkInfo _networkInfo;
  final VocabularyLocalDataSource _localDataSource;

  QuizRepositoryImpl({
    required QuizRemoteDataSource remoteDataSource,
    required AuthLocalDataSource authLocalDataSource,
    required NetworkInfo networkInfo,
    required VocabularyLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _authLocalDataSource = authLocalDataSource,
       _networkInfo = networkInfo,
       _localDataSource = localDataSource;

  @override
  Future<Either<Failure, List<QuizQuestionEntity>>> getQuestions({
    required String bankId,
  }) async {
    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      return const Left(
        NetworkFailure('Không có kết nối mạng. Vui lòng thử lại.'),
      );
    }

    try {
      final token = await _authLocalDataSource.getAccessToken();
      if (token == null) {
        return const Left(AuthFailure('Phiên đăng nhập đã hết hạn.'));
      }

      final questions = await _remoteDataSource.getQuestions(
        bankId: bankId,
        token: token,
      );
      return Right(questions);
    } catch (e) {
      return Left(ServerFailure('Không thể tải câu hỏi: $e'));
    }
  }

  @override
  Future<Either<Failure, QuizResultEntity>> submitResult({
    required QuizResultEntity result,
  }) async {
    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      await _saveLocalResult(result, isSynced: false);
      return Right(result);
    }

    try {
      final token = await _authLocalDataSource.getAccessToken();
      if (token == null) {
        await _saveLocalResult(result, isSynced: false);
        return Right(result);
      }

      final submitted = await _remoteDataSource.submitResult(
        result: result,
        token: token,
      );
      await _saveLocalResult(submitted, isSynced: submitted.backendId != null);
      return Right(submitted);
    } catch (e) {
      await _saveLocalResult(result, isSynced: false);
      return Right(result);
    }
  }

  Future<void> _saveLocalResult(
    QuizResultEntity result, {
    required bool isSynced,
  }) async {
    final completedAt = result.completedAt ?? DateTime.now();
    final backendId =
        result.backendId ?? 'local_${completedAt.microsecondsSinceEpoch}';

    await _localDataSource.saveQuizResult(
      QuizResultModel(
        backendId: backendId,
        bankBackendId: result.bankId,
        bankTitle: await _resolveBankTitle(result.bankId),
        totalQuestions: result.totalQuestions,
        correctAnswers: result.correctCount,
        score: result.score,
        durationSeconds: result.timeTakenSeconds,
        status: result.status,
        answers: result.selectedAnswers.entries
            .map(
              (entry) => QuizAnswerItem(
                questionBackendId: entry.key,
                selectedAnswer: entry.value,
              ),
            )
            .toList(),
        completedAt: completedAt,
        isSynced: isSynced,
      ),
    );
  }

  Future<String> _resolveBankTitle(String bankId) async {
    try {
      final banks = await _localDataSource.getAllBanks();
      for (final bank in banks) {
        if (bank.backendId == bankId) {
          return bank.title;
        }
      }
    } catch (_) {}
    return 'Bộ đề $bankId';
  }
}
