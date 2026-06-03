import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/ocr/data/datasources/ocr_remote_datasource.dart';
import 'package:frontend/features/ocr/domain/entities/ocr_entity.dart';
import 'package:frontend/features/ocr/domain/repositories/ocr_repository.dart';
import 'package:frontend/features/translation/data/datasources/translation_remote_datasource.dart';
import 'package:frontend/features/translation/domain/entities/translation_entity.dart';

/// Implements [OcrRepository] by coordinating remote data sources.
///
/// - Checks network connectivity before any API call.
/// - Retrieves auth token from secure storage.
/// - Catches exceptions from data sources and converts them to [Failure].
class OcrRepositoryImpl implements OcrRepository {
  final OcrRemoteDataSource _ocrRemoteDataSource;
  final TranslationRemoteDataSource _translationRemoteDataSource;
  final AuthLocalDataSource _authLocalDataSource;
  final NetworkInfo _networkInfo;

  const OcrRepositoryImpl({
    required OcrRemoteDataSource ocrRemoteDataSource,
    required TranslationRemoteDataSource translationRemoteDataSource,
    required AuthLocalDataSource authLocalDataSource,
    required NetworkInfo networkInfo,
  }) : _ocrRemoteDataSource = ocrRemoteDataSource,
       _translationRemoteDataSource = translationRemoteDataSource,
       _authLocalDataSource = authLocalDataSource,
       _networkInfo = networkInfo;

  @override
  Future<Either<Failure, OcrTranslationEntity>> translateImage({
    required Uint8List imageBytes,
    required String filename,
    required String sourceLanguage,
    required String targetLanguage,
    required void Function(double progress) onProgress,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final authToken = await _authLocalDataSource.getAccessToken();

      final result = await _ocrRemoteDataSource.translateImage(
        imageBytes: imageBytes,
        filename: filename,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        authToken: authToken,
        onProgress: onProgress,
      );

      return Right(
        OcrTranslationEntity(
          extractedText: result.extractedText,
          translatedText: result.translatedText,
          imageBytes: imageBytes,
          sourceLanguage: result.sourceLanguage,
          targetLanguage: result.targetLanguage,
          confidence: result.confidence,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TranslationEntity>> retranslateText({
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
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        authToken: authToken,
      );

      return Right(translation);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(ServerFailure('Không thể dịch lại: ${e.toString()}'));
    }
  }
}
