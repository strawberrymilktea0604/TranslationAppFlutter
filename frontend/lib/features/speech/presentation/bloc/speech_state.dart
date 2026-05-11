part of 'speech_cubit.dart';

sealed class SpeechState {
  const SpeechState();
}

/// Idle — no recording in progress.
final class SpeechInitial extends SpeechState {
  const SpeechInitial();
}

/// Microphone is active and capturing audio.
final class SpeechListening extends SpeechState {
  /// Partial (live) transcript from STT engine.
  final String partialText;

  /// Normalised sound level: 0.0 (silent) → 1.0 (loud).
  final double amplitude;

  final String srcLang;
  final String tgtLang;

  const SpeechListening({
    required this.partialText,
    required this.amplitude,
    required this.srcLang,
    required this.tgtLang,
  });

  SpeechListening copyWith({
    String? partialText,
    double? amplitude,
    String? srcLang,
    String? tgtLang,
  }) =>
      SpeechListening(
        partialText: partialText ?? this.partialText,
        amplitude: amplitude ?? this.amplitude,
        srcLang: srcLang ?? this.srcLang,
        tgtLang: tgtLang ?? this.tgtLang,
      );
}

/// Audio uploaded, STT + translation in progress on server.
final class SpeechTranslating extends SpeechState {
  final String recognisedText;
  final String srcLang;
  final String tgtLang;

  const SpeechTranslating({
    required this.recognisedText,
    required this.srcLang,
    required this.tgtLang,
  });
}

/// User edited the recognised text and re-translation is in progress.
final class SpeechRetranslating extends SpeechState {
  /// The user-edited source text.
  final String editedText;
  final String srcLang;
  final String tgtLang;

  const SpeechRetranslating({
    required this.editedText,
    required this.srcLang,
    required this.tgtLang,
  });
}

/// Translation completed.
final class SpeechSuccess extends SpeechState {
  final String recognisedText;
  final String translatedText;
  final String srcLang;
  final String tgtLang;

  const SpeechSuccess({
    required this.recognisedText,
    required this.translatedText,
    required this.srcLang,
    required this.tgtLang,
  });
}

/// Something went wrong.
final class SpeechFailure extends SpeechState {
  final String message;
  const SpeechFailure(this.message);
}
