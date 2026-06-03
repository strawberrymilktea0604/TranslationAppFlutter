import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/speech/domain/repositories/speech_repository.dart';
import 'package:frontend/features/translation/domain/entities/translation_entity.dart';

/// Parameters for [RetranslateVoiceTextUseCase].
class RetranslateVoiceParams extends Equatable {
  /// The user-edited source text.
  final String text;

  /// Source language code.
  final String sourceLanguage;

  /// Target language code.
  final String targetLanguage;

  const RetranslateVoiceParams({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  List<Object?> get props => [text, sourceLanguage, targetLanguage];
}

/// Re-translates previously recognised text after user edits.
///
/// Used when the user corrects misrecognised words from STT
/// before saving to flashcards.
class RetranslateVoiceTextUseCase
    extends UseCase<TranslationEntity, RetranslateVoiceParams> {
  final SpeechRepository _repository;

  RetranslateVoiceTextUseCase(this._repository);

  @override
  Future<Either<Failure, TranslationEntity>> call(
    RetranslateVoiceParams params,
  ) {
    return _repository.retranslateText(
      text: params.text,
      sourceLanguage: params.sourceLanguage,
      targetLanguage: params.targetLanguage,
    );
  }
}
