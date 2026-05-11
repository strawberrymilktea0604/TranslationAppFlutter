import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// State for [RecordingCubit] following Bloc naming conventions.
///
/// Uses sealed class approach for type-safe exhaustive switch.
/// Each state represents a snapshot of the audio recording status.
@immutable
sealed class RecordingState extends Equatable {
  const RecordingState();
}

/// Initial/idle state — no recording in progress.
final class RecordingIdle extends RecordingState {
  const RecordingIdle();

  @override
  List<Object?> get props => [];
}

/// Microphone permission has not been granted.
///
/// The UI should display a prompt explaining why the app needs
/// microphone access and offer a button to request permission.
final class RecordingPermissionDenied extends RecordingState {
  const RecordingPermissionDenied();

  @override
  List<Object?> get props => [];
}

/// Actively recording audio from the microphone.
///
/// Stores the elapsed duration so the UI can display a timer.
final class RecordingInProgress extends RecordingState {
  /// How long the recording has been running.
  final Duration elapsed;

  const RecordingInProgress({this.elapsed = Duration.zero});

  @override
  List<Object?> get props => [elapsed];
}

/// Recording is paused.
///
/// Stores the elapsed duration at the moment of pause.
final class RecordingPaused extends RecordingState {
  /// Elapsed duration when the recording was paused.
  final Duration elapsed;

  const RecordingPaused({this.elapsed = Duration.zero});

  @override
  List<Object?> get props => [elapsed];
}

/// Recording completed successfully — file is ready.
final class RecordingSuccess extends RecordingState {
  /// Absolute path to the recorded audio file.
  final String filePath;

  /// Duration of the recorded audio.
  final Duration duration;

  const RecordingSuccess({
    required this.filePath,
    required this.duration,
  });

  @override
  List<Object?> get props => [filePath, duration];
}

/// Recording failed with an error.
final class RecordingFailure extends RecordingState {
  /// Human-readable error message.
  final String message;

  const RecordingFailure(this.message);

  @override
  List<Object?> get props => [message];
}
