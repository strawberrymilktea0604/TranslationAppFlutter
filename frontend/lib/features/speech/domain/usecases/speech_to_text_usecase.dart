import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/speech/domain/entities/speech_entity.dart';
import 'package:frontend/features/speech/domain/repositories/speech_repository.dart';

/// Parameters for [SpeechTranslateUseCase].
class SpeechTranslateParams extends Equatable {
  /// Absolute path to the recorded audio file on disk.
  final String audioFilePath;

  /// Source language code (e.g. 'vi'). Null for auto-detection.
  final String? sourceLanguage;

  /// Target language code (e.g. 'en').
  final String targetLanguage;

  const SpeechTranslateParams({
    required this.audioFilePath,
    this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  List<Object?> get props => [audioFilePath, sourceLanguage, targetLanguage];
}

/// UC05 — Uploads recorded audio for STT + translation.
///
/// Requires authenticated user and network connectivity.
class SpeechTranslateUseCase
    extends UseCase<SpeechTranslationEntity, SpeechTranslateParams> {
  final SpeechRepository _repository;

  SpeechTranslateUseCase(this._repository);

  @override
  Future<Either<Failure, SpeechTranslationEntity>> call(
    SpeechTranslateParams params,
  ) {
    return _repository.translateVoice(
      audioFilePath: params.audioFilePath,
      sourceLanguage: params.sourceLanguage,
      targetLanguage: params.targetLanguage,
    );
  }
}
