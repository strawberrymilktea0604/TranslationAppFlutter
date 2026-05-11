import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/speech/data/datasources/speech_remote_datasource.dart';
import 'package:frontend/features/speech/domain/entities/speech_entity.dart';
import 'package:frontend/features/speech/domain/repositories/speech_repository.dart';
import 'package:frontend/features/translation/data/datasources/translation_remote_datasource.dart';

/// Implements [SpeechRepository] by coordinating remote data sources.
///
/// - Checks network connectivity before any API call.
/// - Retrieves auth token from secure storage.
/// - Catches exceptions from data sources and converts them to [Failure].
class SpeechRepositoryImpl implements SpeechRepository {
  final SpeechRemoteDataSource _speechRemoteDataSource;
  final TranslationRemoteDataSource _translationRemoteDataSource;
  final AuthLocalDataSource _authLocalDataSource;
  final NetworkInfo _networkInfo;

  const SpeechRepositoryImpl({
    required SpeechRemoteDataSource speechRemoteDataSource,
    required TranslationRemoteDataSource translationRemoteDataSource,
    required AuthLocalDataSource authLocalDataSource,
    required NetworkInfo networkInfo,
  })  : _speechRemoteDataSource = speechRemoteDataSource,
        _translationRemoteDataSource = translationRemoteDataSource,
        _authLocalDataSource = authLocalDataSource,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, SpeechTranslationEntity>> translateVoice({
    required String audioFilePath,
    String? sourceLanguage,
    required String targetLanguage,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final authToken = await _authLocalDataSource.getAccessToken();

      final result = await _speechRemoteDataSource.translateVoice(
        audioFilePath: audioFilePath,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        authToken: authToken,
      );

      return Right(SpeechTranslationEntity(
        sourceText: result.sourceText,
        translatedText: result.translatedText,
        sourceLanguage: result.sourceLanguage,
        targetLanguage: result.targetLanguage,
        sttLanguageProbability: result.sttLanguageProbability,
        isCached: result.isCached,
        responseTimeMs: result.responseTimeMs,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> retranslateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final authToken = await _authLocalDataSource.getAccessToken();

      final translation = await _translationRemoteDataSource.translateText(
        text: text.trim(),
        sourceLanguage: sourceLanguage == 'auto' ? 'en' : sourceLanguage,
        targetLanguage: targetLanguage,
        authToken: authToken,
      );

      return Right(translation.translatedText);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(ServerFailure('Không thể dịch lại: ${e.toString()}'));
    }
  }
}
