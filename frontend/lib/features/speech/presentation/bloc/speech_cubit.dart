import 'package:bloc/bloc.dart';

import 'package:frontend/features/speech/domain/usecases/speech_to_text_usecase.dart';
import 'package:frontend/features/speech/domain/usecases/retranslate_voice_text_usecase.dart';
import 'package:frontend/features/history/domain/entities/history_entity.dart' as frontend_history;
import 'package:frontend/features/history/domain/repositories/history_repository.dart' as frontend_history;
import 'package:frontend/injection_container.dart';

part 'speech_state.dart';

/// Cubit managing the voice translation pipeline (UC05).
///
/// Supports two modes:
/// 1. **Backend API mode** — records audio locally, uploads to
///    `/api/v1/audio/translate/voice` for STT + translation.
/// 2. **Re-translate mode** — when the user edits the recognised text,
///    calls text translation API without re-uploading audio.
///
/// Clean Architecture flow:
///   UI → SpeechCubit → UseCase → Repository → DataSource
class SpeechCubit extends Cubit<SpeechState> {
  final SpeechTranslateUseCase _speechTranslateUseCase;
  final RetranslateVoiceTextUseCase _retranslateUseCase;

  SpeechCubit({
    required SpeechTranslateUseCase speechTranslateUseCase,
    required RetranslateVoiceTextUseCase retranslateUseCase,
  })  : _speechTranslateUseCase = speechTranslateUseCase,
        _retranslateUseCase = retranslateUseCase,
        super(const SpeechInitial());

  // -------------------------------------------------------------------------
  // Upload recorded audio for STT + translation
  // -------------------------------------------------------------------------

  /// Uploads the audio file at [audioFilePath] to the backend
  /// for Speech-to-Text extraction and translation.
  ///
  /// Emits [SpeechTranslating] → [SpeechSuccess] or [SpeechFailure].
  Future<void> translateAudio({
    required String audioFilePath,
    required String srcLang,
    required String tgtLang,
  }) async {
    emit(SpeechTranslating(
      recognisedText: '',
      srcLang: srcLang,
      tgtLang: tgtLang,
    ));

    final result = await _speechTranslateUseCase(SpeechTranslateParams(
      audioFilePath: audioFilePath,
      sourceLanguage: srcLang == 'auto' ? null : srcLang,
      targetLanguage: tgtLang,
    ));

    if (isClosed) return;

    result.fold(
      (failure) => emit(SpeechFailure(failure.message)),
      (entity) {
        if (entity.sourceText.trim().isEmpty) {
          emit(const SpeechFailure(
            'Không nhận diện được giọng nói. '
            'Hãy nói rõ hơn và thử lại.',
          ));
          return;
        }
        emit(SpeechSuccess(
          recognisedText: entity.sourceText,
          translatedText: entity.translatedText,
          srcLang: entity.sourceLanguage,
          tgtLang: entity.targetLanguage,
        ));

        // Lưu lịch sử
        try {
          final historyEntity = frontend_history.HistoryEntity(
            isarId: 0,
            sourceText: entity.sourceText,
            translatedText: entity.translatedText,
            sourceLanguage: entity.sourceLanguage,
            targetLanguage: entity.targetLanguage,
            translationType: 'voice',
            createdAt: DateTime.now(),
            isSynced: false,
          );
          sl<frontend_history.HistoryRepository>().saveHistory(historyEntity);
        } catch (_) {}
      },
    );
  }

  // -------------------------------------------------------------------------
  // Re-translate after user edits the recognised text
  // -------------------------------------------------------------------------

  /// Re-translates user-edited text without re-uploading audio.
  ///
  /// Used when STT misrecognised some words and the user corrects
  /// them before saving to flashcards.
  Future<void> retranslate({
    required String editedText,
    required String srcLang,
    required String tgtLang,
  }) async {
    if (editedText.trim().isEmpty) return;

    emit(SpeechRetranslating(
      editedText: editedText,
      srcLang: srcLang,
      tgtLang: tgtLang,
    ));

    final result = await _retranslateUseCase(RetranslateVoiceParams(
      text: editedText.trim(),
      sourceLanguage: srcLang,
      targetLanguage: tgtLang,
    ));

    if (isClosed) return;

    result.fold(
      (failure) => emit(SpeechFailure(failure.message)),
      (translatedText) {
        emit(SpeechSuccess(
          recognisedText: editedText,
          translatedText: translatedText,
          srcLang: srcLang,
          tgtLang: tgtLang,
        ));

        // Lưu lịch sử
        try {
          final historyEntity = frontend_history.HistoryEntity(
            isarId: 0,
            sourceText: editedText,
            translatedText: translatedText,
            sourceLanguage: srcLang,
            targetLanguage: tgtLang,
            translationType: 'voice',
            createdAt: DateTime.now(),
            isSynced: false,
          );
          sl<frontend_history.HistoryRepository>().saveHistory(historyEntity);
        } catch (_) {}
      },
    );
  }

  // -------------------------------------------------------------------------
  // Reset
  // -------------------------------------------------------------------------

  /// Resets to initial state.
  void reset() {
    if (!isClosed) emit(const SpeechInitial());
  }
}
