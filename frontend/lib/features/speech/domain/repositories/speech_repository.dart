import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/speech/domain/entities/speech_entity.dart';
import 'package:frontend/features/translation/domain/entities/translation_entity.dart';

/// Abstract repository for Speech-to-Text operations (UC05).
///
/// Requires Auth. Requires Network.
/// The audio file is uploaded to `POST /api/v1/audio/translate/voice`
/// for STT + translation in a single server round-trip.
abstract class SpeechRepository {
  /// Uploads an audio file for STT extraction + translation.
  ///
  /// [audioFilePath] — absolute path to the recorded audio file.
  /// [sourceLanguage] — optional; auto-detected if `null`.
  /// [targetLanguage] — required target translation language.
  Future<Either<Failure, SpeechTranslationEntity>> translateVoice({
    required String audioFilePath,
    String? sourceLanguage,
    required String targetLanguage,
  });

  /// Re-translates previously recognised text after user edits.
  ///
  /// Used when the user corrects misrecognised words before saving.
  Future<Either<Failure, TranslationEntity>> retranslateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });
}
