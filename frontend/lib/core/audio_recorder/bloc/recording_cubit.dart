import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/audio_recorder/audio_recorder_service.dart';
import 'package:frontend/core/audio_recorder/bloc/recording_state.dart';

/// Manages audio recording state across the application.
///
/// This Cubit orchestrates the [AudioRecorderService] and exposes
/// a clean state stream to the UI. It handles:
/// - Permission checking before recording starts.
/// - Start / stop / cancel / pause / resume lifecycle.
/// - An internal timer to track elapsed recording duration.
///
/// Registered as a **Factory** in DI so each screen that needs
/// recording gets its own instance (avoids state leaks between
/// screens).
///
/// Flow: UI button tap → [startRecording] / [stopRecording] /
///       [cancelRecording] → emit state.
class RecordingCubit extends Cubit<RecordingState> {
  final AudioRecorderService _recorderService;

  /// Periodic timer that updates elapsed duration every second.
  Timer? _elapsedTimer;

  /// Tracks when the recording started for elapsed calculation.
  DateTime? _recordingStartTime;

  /// Accumulated paused duration for accurate elapsed tracking.
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;

  RecordingCubit({required AudioRecorderService recorderService})
      : _recorderService = recorderService,
        super(const RecordingIdle());

  /// Checks microphone permission and starts recording if granted.
  ///
  /// Emits [RecordingPermissionDenied] if permission is not granted.
  /// Emits [RecordingInProgress] once recording starts.
  /// Emits [RecordingFailure] if an error occurs.
  Future<void> startRecording() async {
    try {
      // Check permission first.
      final hasPermission = await _recorderService.hasPermission();
      if (!hasPermission) {
        emit(const RecordingPermissionDenied());
        return;
      }

      await _recorderService.startRecording();

      _recordingStartTime = DateTime.now();
      _pausedDuration = Duration.zero;
      _pauseStartTime = null;

      emit(const RecordingInProgress());
      _startElapsedTimer();
    } on StateError catch (e) {
      developer.log(
        'Recording start error: $e',
        name: 'RecordingCubit',
        level: 900,
      );
      emit(RecordingFailure(e.message));
    } on Exception catch (e) {
      developer.log(
        'Recording start error: $e',
        name: 'RecordingCubit',
        level: 900,
      );
      emit(RecordingFailure(e.toString()));
    }
  }

  /// Stops recording and emits [RecordingSuccess] with the file path.
  ///
  /// Emits [RecordingFailure] if no file was produced.
  Future<void> stopRecording() async {
    _stopElapsedTimer();

    // Account for any remaining pause.
    if (_pauseStartTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartTime!);
      _pauseStartTime = null;
    }

    try {
      final result = await _recorderService.stopRecording();

      if (result == null) {
        emit(const RecordingFailure(
          'Recording stopped but no audio file was produced.',
        ));
        return;
      }

      developer.log(
        'Recording complete: ${result.filePath} '
        '(${result.duration.inSeconds}s)',
        name: 'RecordingCubit',
      );

      emit(RecordingSuccess(
        filePath: result.filePath,
        duration: result.duration,
      ));
    } on Exception catch (e) {
      developer.log(
        'Recording stop error: $e',
        name: 'RecordingCubit',
        level: 900,
      );
      emit(RecordingFailure(e.toString()));
    }
  }

  /// Cancels the current recording and returns to idle.
  ///
  /// The temp audio file is deleted automatically by the service.
  Future<void> cancelRecording() async {
    _stopElapsedTimer();

    try {
      await _recorderService.cancelRecording();
      emit(const RecordingIdle());
    } on Exception catch (e) {
      developer.log(
        'Recording cancel error: $e',
        name: 'RecordingCubit',
        level: 900,
      );
      emit(RecordingFailure(e.toString()));
    }
  }

  /// Pauses the recording.
  Future<void> pauseRecording() async {
    if (state is! RecordingInProgress) return;

    try {
      await _recorderService.pauseRecording();
      _pauseStartTime = DateTime.now();

      final elapsed = _calculateElapsed();
      _stopElapsedTimer();

      emit(RecordingPaused(elapsed: elapsed));
    } on Exception catch (e) {
      developer.log(
        'Recording pause error: $e',
        name: 'RecordingCubit',
        level: 900,
      );
      emit(RecordingFailure(e.toString()));
    }
  }

  /// Resumes a paused recording.
  Future<void> resumeRecording() async {
    if (state is! RecordingPaused) return;

    try {
      // Track paused duration.
      if (_pauseStartTime != null) {
        _pausedDuration += DateTime.now().difference(_pauseStartTime!);
        _pauseStartTime = null;
      }

      await _recorderService.resumeRecording();

      emit(RecordingInProgress(elapsed: _calculateElapsed()));
      _startElapsedTimer();
    } on Exception catch (e) {
      developer.log(
        'Recording resume error: $e',
        name: 'RecordingCubit',
        level: 900,
      );
      emit(RecordingFailure(e.toString()));
    }
  }

  /// Resets the cubit to idle state.
  ///
  /// Useful after the UI has consumed [RecordingSuccess] or
  /// [RecordingFailure] to allow starting a new recording.
  void reset() {
    _stopElapsedTimer();
    _recordingStartTime = null;
    _pausedDuration = Duration.zero;
    _pauseStartTime = null;
    emit(const RecordingIdle());
  }

  /// Requests microphone permission without starting a recording.
  ///
  /// Returns `true` if permission was granted.
  Future<bool> requestPermission() async {
    final granted = await _recorderService.hasPermission();
    if (!granted) {
      emit(const RecordingPermissionDenied());
    }
    return granted;
  }

  /// Calculates the elapsed recording duration, excluding pauses.
  Duration _calculateElapsed() {
    if (_recordingStartTime == null) return Duration.zero;

    final totalElapsed = DateTime.now().difference(_recordingStartTime!);
    final activePause = _pauseStartTime != null
        ? DateTime.now().difference(_pauseStartTime!)
        : Duration.zero;

    return totalElapsed - _pausedDuration - activePause;
  }

  /// Starts a periodic timer that updates the elapsed duration
  /// every second while recording is in progress.
  void _startElapsedTimer() {
    _stopElapsedTimer();
    _elapsedTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!isClosed && state is RecordingInProgress) {
          emit(RecordingInProgress(elapsed: _calculateElapsed()));
        }
      },
    );
  }

  /// Cancels the elapsed timer.
  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  @override
  Future<void> close() async {
    _stopElapsedTimer();
    // Do not dispose _recorderService here because it is a singleton
    // and will be reused by future instances of RecordingCubit.
    if (state is RecordingInProgress) {
      try {
        await _recorderService.cancelRecording();
      } catch (_) {}
    }
    return super.close();
  }
}
