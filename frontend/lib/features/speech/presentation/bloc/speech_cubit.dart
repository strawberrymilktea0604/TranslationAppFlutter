import 'dart:math' as math;

import 'package:bloc/bloc.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:frontend/features/translation/data/datasources/translation_remote_datasource.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';

part 'speech_state.dart';

class SpeechCubit extends Cubit<SpeechState> {
  final TranslationRemoteDataSource _translationDataSource;
  final AuthLocalDataSource _authLocalDataSource;
  final SpeechToText _stt = SpeechToText();

  SpeechCubit({
    required TranslationRemoteDataSource translationDataSource,
    required AuthLocalDataSource authLocalDataSource,
  })  : _translationDataSource = translationDataSource,
        _authLocalDataSource = authLocalDataSource,
        super(SpeechInitial());

  // -------------------------------------------------------------------------
  // Start listening
  // -------------------------------------------------------------------------

  Future<void> startListening({
    required String srcLang,
    required String tgtLang,
  }) async {
    if (state is SpeechListening) return;

    // 1. Init STT engine
    final available = await _stt.initialize(
      onError: (error) {
        if (!isClosed) {
          emit(SpeechFailure(error.errorMsg));
        }
      },
    );

    if (!available) {
      emit(const SpeechFailure('Thiết bị không hỗ trợ nhận dạng giọng nói.'));
      return;
    }

    emit(SpeechListening(
      partialText: '',
      amplitude: 0.0,
      srcLang: srcLang,
      tgtLang: tgtLang,
    ));

    // Convert lang code → BCP-47 locale (e.g. 'en' → 'en_US', 'vi' → 'vi_VN')
    final localeId = _toLocale(srcLang);

    await _stt.listen(
      localeId: localeId,
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(seconds: 3),
      // Called continuously while listening
      onResult: (SpeechRecognitionResult result) {
        if (!isClosed) {
          if (result.finalResult) {
            // User stopped speaking — begin translation
            final text = result.recognizedWords.trim();
            if (text.isNotEmpty) {
              _translate(text, srcLang, tgtLang);
            } else {
              emit(SpeechInitial());
            }
          } else {
            final current = state as SpeechListening;
            emit(current.copyWith(partialText: result.recognizedWords));
          }
        }
      },
      // Called every ~60ms with current amplitude (0.0 - 10.0)
      onSoundLevelChange: (double level) {
        if (!isClosed && state is SpeechListening) {
          final current = state as SpeechListening;
          // Normalise to 0.0–1.0
          final amplitude = (level / 10.0).clamp(0.0, 1.0);
          emit(current.copyWith(amplitude: amplitude));
        }
      },
    );
  }

  // -------------------------------------------------------------------------
  // Stop listening manually
  // -------------------------------------------------------------------------

  Future<void> stopListening() async {
    await _stt.stop();
    if (!isClosed && state is SpeechListening) {
      final current = state as SpeechListening;
      final text = current.partialText.trim();
      if (text.isNotEmpty) {
        _translate(text, current.srcLang, current.tgtLang);
      } else {
        emit(SpeechInitial());
      }
    }
  }

  // -------------------------------------------------------------------------
  // Cancel
  // -------------------------------------------------------------------------

  Future<void> cancel() async {
    await _stt.cancel();
    if (!isClosed) emit(SpeechInitial());
  }

  // -------------------------------------------------------------------------
  // Reset to initial
  // -------------------------------------------------------------------------

  void reset() {
    _stt.cancel();
    if (!isClosed) emit(SpeechInitial());
  }

  // -------------------------------------------------------------------------
  // Internal: translate recognised text
  // -------------------------------------------------------------------------

  Future<void> _translate(
      String recognisedText, String srcLang, String tgtLang) async {
    emit(SpeechTranslating(
      recognisedText: recognisedText,
      srcLang: srcLang,
      tgtLang: tgtLang,
    ));

    try {
      final token = await _authLocalDataSource.getAccessToken();
      final result = await _translationDataSource.translateText(
        text: recognisedText,
        sourceLanguage: srcLang == 'auto' ? 'en' : srcLang,
        targetLanguage: tgtLang,
        authToken: token,
      );

      if (!isClosed) {
        emit(SpeechSuccess(
          recognisedText: recognisedText,
          translatedText: result.translatedText,
          srcLang: srcLang,
          tgtLang: tgtLang,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(SpeechFailure('Không thể dịch: ${e.toString()}'));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static String _toLocale(String code) {
    const map = {
      'en': 'en_US',
      'vi': 'vi_VN',
      'fr': 'fr_FR',
      'ja': 'ja_JP',
      'ko': 'ko_KR',
      'zh': 'zh_CN',
      'de': 'de_DE',
      'es': 'es_ES',
      'auto': 'en_US',
    };
    return map[code] ?? 'en_US';
  }

  @override
  Future<void> close() {
    _stt.cancel();
    return super.close();
  }
}
