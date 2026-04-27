import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// State for [TtsCubit] following Bloc naming conventions.
///
/// Uses sealed class approach for type-safe exhaustive switch.
/// Each state represents a snapshot of the TTS playback status.
@immutable
sealed class TtsState extends Equatable {
  const TtsState();
}

/// Initial/idle state — no speech is playing.
final class TtsIdle extends TtsState {
  const TtsIdle();

  @override
  List<Object?> get props => [];
}

/// Speaking state — TTS engine is actively reading text.
///
/// Stores the text and language being spoken so the UI can
/// show which button is active (source vs target).
final class TtsSpeaking extends TtsState {
  /// The text currently being spoken.
  final String text;

  /// The language code of the text being spoken.
  final String languageCode;

  const TtsSpeaking({required this.text, required this.languageCode});

  @override
  List<Object?> get props => [text, languageCode];
}

/// Error state — TTS playback failed.
final class TtsFailure extends TtsState {
  final String message;

  const TtsFailure(this.message);

  @override
  List<Object?> get props => [message];
}
