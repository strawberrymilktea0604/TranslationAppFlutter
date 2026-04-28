import 'dart:developer' as developer;

import 'package:flutter_tts/flutter_tts.dart';

/// Abstraction over TTS engine to enable testability.
///
/// Placed in `core/tts` because TTS is a shared utility
/// that can be used across multiple features (translation,
/// vocabulary, history).
abstract class TtsService {
  /// Speaks [text] using the voice/locale for [languageCode].
  ///
  /// Supported [languageCode] values: 'en', 'vi', 'fr', 'ja',
  /// 'ko', 'zh', 'de', 'es'. Falls back to 'en' if unsupported.
  Future<void> speak(String text, {required String languageCode});

  /// Stops any ongoing speech immediately.
  Future<void> stop();

  /// Whether the TTS engine is currently speaking.
  bool get isSpeaking;

  /// Releases TTS engine resources. Call on app shutdown.
  Future<void> dispose();

  /// Registers a callback invoked when speech finishes.
  void setOnComplete(void Function() onComplete);

  /// Registers a callback invoked when speech is cancelled.
  void setOnCancel(void Function() onCancel);

  /// Registers a callback invoked on TTS engine error.
  void setOnError(void Function(String message) onError);
}

/// Production implementation of [TtsService] backed by `flutter_tts`.
///
/// Configures voice parameters per language code to ensure natural
/// pronunciation across all supported languages.
class TtsServiceImpl implements TtsService {
  final FlutterTts _tts;
  bool _speaking = false;

  TtsServiceImpl({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _init();
  }

  Future<void> _init() async {
    // Await completion to ensure completion handlers fire on all platforms
    await _tts.awaitSpeakCompletion(true);
    // Set default speech rate & pitch for natural sounding speech.
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      _speaking = true;
    });

    _tts.setCompletionHandler(() {
      _speaking = false;
    });

    _tts.setCancelHandler(() {
      _speaking = false;
    });

    _tts.setErrorHandler((message) {
      _speaking = false;
      developer.log(
        'TTS Error: $message',
        name: 'TtsService',
        level: 900,
      );
    });
  }

  /// Maps app language codes (ISO 639-1) to BCP-47 locale tags
  /// used by the TTS engine.
  ///
  /// Uses specific regional variants to get the best quality voice
  /// on each platform.
  static const Map<String, String> _languageLocaleMap = {
    'en': 'en-US',
    'vi': 'vi-VN',
    'fr': 'fr-FR',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'zh': 'zh-CN',
    'de': 'de-DE',
    'es': 'es-ES',
  };

  /// Optimal speech rate per language.
  /// Some languages (e.g. Japanese, Chinese) sound better slower.
  static const Map<String, double> _languageSpeechRates = {
    'en': 0.45,
    'vi': 0.45,
    'fr': 0.42,
    'ja': 0.40,
    'ko': 0.42,
    'zh': 0.40,
    'de': 0.42,
    'es': 0.45,
  };

  @override
  Future<void> speak(String text, {required String languageCode}) async {
    if (text.trim().isEmpty) {
      return;
    }

    // Stop any ongoing speech first.
    if (_speaking) {
      await stop();
    }

    // Resolve locale; fall back to en-US for unknown codes.
    final locale = _languageLocaleMap[languageCode] ?? 'en-US';
    final rate = _languageSpeechRates[languageCode] ?? 0.45;

    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(rate);

    developer.log(
      'Speaking in $locale (rate=$rate): '
      '${text.length > 50 ? '${text.substring(0, 50)}...' : text}',
      name: 'TtsService',
    );

    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _speaking = false;
  }

  @override
  bool get isSpeaking => _speaking;

  @override
  Future<void> dispose() async {
    await stop();
  }

  @override
  void setOnComplete(void Function() onComplete) {
    _tts.setCompletionHandler(() {
      _speaking = false;
      onComplete();
    });
  }

  @override
  void setOnCancel(void Function() onCancel) {
    _tts.setCancelHandler(() {
      _speaking = false;
      onCancel();
    });
  }

  @override
  void setOnError(void Function(String message) onError) {
    _tts.setErrorHandler((message) {
      _speaking = false;
      onError(message);
    });
  }
}
