import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/tts/tts_service.dart';
import 'package:frontend/core/tts/bloc/tts_state.dart';

/// Manages TTS playback state across the application.
///
/// This Cubit is registered as a **LazySingleton** in the DI
/// container so a single instance is shared app-wide. This
/// prevents overlapping speech from multiple screens.
///
/// Flow: UI button tap → [speak] / [stop] → emit state.
class TtsCubit extends Cubit<TtsState> {
  final TtsService _ttsService;

  TtsCubit({required TtsService ttsService})
      : _ttsService = ttsService,
        super(const TtsIdle()) {
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _ttsService.setOnComplete(() {
      if (!isClosed) {
        emit(const TtsIdle());
      }
    });

    _ttsService.setOnCancel(() {
      if (!isClosed) {
        emit(const TtsIdle());
      }
    });

    _ttsService.setOnError((message) {
      if (!isClosed) {
        emit(TtsFailure(message));
      }
    });
  }

  /// Speaks [text] using the voice for [languageCode].
  ///
  /// If already speaking the same text+language, stops playback
  /// instead (toggle behavior). If speaking something else, stops
  /// the current speech and starts the new one.
  Future<void> speak({
    required String text,
    required String languageCode,
  }) async {
    if (text.trim().isEmpty) {
      return;
    }

    // Toggle: if already speaking this exact text, stop.
    final current = state;
    if (current is TtsSpeaking &&
        current.text == text &&
        current.languageCode == languageCode) {
      await stop();
      return;
    }

    emit(TtsSpeaking(text: text, languageCode: languageCode));

    try {
      await _ttsService.speak(text, languageCode: languageCode);
    } on Exception catch (e) {
      emit(TtsFailure(e.toString()));
    }
  }

  /// Stops any ongoing speech and returns to idle.
  Future<void> stop() async {
    await _ttsService.stop();
    emit(const TtsIdle());
  }

  /// Whether TTS is currently speaking a specific text+language pair.
  bool isSpeakingText(String text, String languageCode) {
    final current = state;
    return current is TtsSpeaking &&
        current.text == text &&
        current.languageCode == languageCode;
  }

  @override
  Future<void> close() async {
    await _ttsService.dispose();
    return super.close();
  }
}
