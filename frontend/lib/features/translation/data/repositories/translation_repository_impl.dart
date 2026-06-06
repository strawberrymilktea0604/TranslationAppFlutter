import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/translation/data/datasources/translation_remote_datasource.dart';
import 'package:frontend/features/translation/domain/entities/translation_entity.dart';
import 'package:frontend/features/translation/domain/repositories/translation_repository.dart';

/// Concrete implementation of [TranslationRepository].
///
/// Strategy:
/// - Checks connectivity first → [NetworkFailure] if offline.
/// - Reads JWT access token (if available) from [AuthLocalDataSource] so the
///   backend applies User-level rate limits instead of Guest-level.
/// - Delegates to [TranslationRemoteDataSource].
/// - Catches all exceptions and converts to [Failure] subclasses.
/// - [switchLanguages] is a no-op: language state is managed by the UI layer.
class TranslationRepositoryImpl implements TranslationRepository {
  final TranslationRemoteDataSource remoteDataSource;
  final AuthLocalDataSource authLocalDataSource;
  final NetworkInfo networkInfo;

  const TranslationRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, TranslationEntity>> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Không có kết nối internet'));
    }

    try {
      // Read access token — null means Guest mode (still allowed per UC01).
      // Token read failure is intentionally swallowed: if secure storage
      // throws, the user still gets a translation (as Guest).
      String? authToken;
      try {
        authToken = await authLocalDataSource.getAccessToken();
      } catch (_) {
        // Ignore — proceed as Guest.
      }

      final model = await remoteDataSource.translateText(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        authToken: authToken,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException {
      return const Left(NetworkFailure());
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> switchLanguages({
    required String currentSource,
    required String currentTarget,
  }) async {
    // Language switching is managed in the UI layer — no server call needed.
    return const Right(null);
  }
}

