import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/learning/data/datasources/quiz_remote_datasource.dart';
import 'package:frontend/features/learning/domain/entities/quiz_question_entity.dart';
import 'package:frontend/features/learning/domain/entities/quiz_result_entity.dart';
import 'package:frontend/features/learning/domain/repositories/quiz_repository.dart';

/// Implementation of [QuizRepository].
///
/// Uses [QuizRemoteDataSource] for backend communication
/// and [AuthLocalDataSource] for JWT token retrieval.
/// Checks [NetworkInfo] before making remote calls.
class QuizRepositoryImpl implements QuizRepository {
  final QuizRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _authLocalDataSource;
  final NetworkInfo _networkInfo;

  QuizRepositoryImpl({
    required QuizRemoteDataSource remoteDataSource,
    required AuthLocalDataSource authLocalDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _authLocalDataSource = authLocalDataSource,
        _networkInfo = networkInfo;

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
      // Offline: still return success so the UI can show results.
      // The result will be synced later via the sync worker.
      return Right(result);
    }

    try {
      final token = await _authLocalDataSource.getAccessToken();
      if (token == null) {
        // No token — still return result for UI display.
        return Right(result);
      }

      final submitted = await _remoteDataSource.submitResult(
        result: result,
        token: token,
      );
      return Right(submitted);
    } catch (e) {
      // Even if submission fails, return the result so the user
      // can see their score. It will be retried via sync worker.
      return Right(result);
    }
  }
}
