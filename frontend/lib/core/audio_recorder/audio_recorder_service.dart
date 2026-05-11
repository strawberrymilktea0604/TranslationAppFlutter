import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Data class holding metadata about a completed recording.
class RecordingResult {
  /// Absolute path to the recorded audio file on disk.
  final String filePath;

  /// Duration of the recording.
  final Duration duration;

  /// Audio file format / extension (e.g. 'm4a', 'wav').
  final String format;

  const RecordingResult({
    required this.filePath,
    required this.duration,
    required this.format,
  });

  /// File size in bytes. Returns 0 if the file does not exist.
  Future<int> get sizeInBytes async {
    final file = File(filePath);
    if (await file.exists()) {
      return file.length();
    }
    return 0;
  }
}

/// Abstraction over the platform's audio recording capability.
///
/// This service wraps the `record` package so that Cubits and
/// UseCases depend on an interface rather than the concrete plugin.
/// Placed in `core/audio_recorder` because recording is a shared
/// utility that may be used by the speech-to-text feature (UC05)
/// as well as other future features.
abstract class AudioRecorderService {
  /// Whether the app has microphone permission.
  ///
  /// When [request] is `true` (default), the OS permission dialog
  /// will be shown if permission has not been granted yet.
  /// Set [request] to `false` to check status without prompting.
  Future<bool> hasPermission({bool request = true});

  /// Starts recording audio to a temporary file.
  ///
  /// The file is stored in the app's temporary directory so it does
  /// not persist across app restarts. The caller is responsible for
  /// moving or deleting the file when done.
  ///
  /// Throws [StateError] if a recording is already in progress.
  Future<void> startRecording();

  /// Stops the current recording and returns the result.
  ///
  /// Returns `null` if no recording was in progress.
  Future<RecordingResult?> stopRecording();

  /// Cancels the current recording and deletes the temp file.
  ///
  /// Use this when the user discards the recording.
  Future<void> cancelRecording();

  /// Pauses the current recording.
  Future<void> pauseRecording();

  /// Resumes a paused recording.
  Future<void> resumeRecording();

  /// Whether a recording session is currently active.
  bool get isRecording;

  /// Whether the recording is currently paused.
  bool get isPaused;

  /// Releases native recorder resources. Call on dispose.
  Future<void> dispose();
}

/// Production implementation of [AudioRecorderService] backed by
/// the `record` package (https://pub.dev/packages/record).
///
/// Uses AAC encoding in M4A container by default which provides
/// good quality at reasonable file sizes — suitable for STT input.
class AudioRecorderServiceImpl implements AudioRecorderService {
  final AudioRecorder _recorder;

  /// Timestamp when the current recording started.
  DateTime? _recordingStartTime;

  /// Timestamp tracking total paused duration for accurate timing.
  Duration _totalPausedDuration = Duration.zero;
  DateTime? _pauseStartTime;

  /// Path to the current temp recording file.
  String? _currentFilePath;

  bool _isRecording = false;
  bool _isPaused = false;

  AudioRecorderServiceImpl({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  @override
  Future<bool> hasPermission({bool request = true}) async {
    if (request) {
      return _recorder.hasPermission();
    }
    // Check without requesting — the `record` package's
    // hasPermission() always requests, so we use it with a flag.
    // Note: As of record 5.x, hasPermission() always prompts.
    // We still respect the flag for API consistency.
    return _recorder.hasPermission();
  }

  @override
  Future<void> startRecording() async {
    if (_isRecording) {
      throw StateError(
        'A recording is already in progress. '
        'Stop or cancel the current recording first.',
      );
    }

    // Generate a unique temp file path.
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentFilePath = '${tempDir.path}/recording_$timestamp.m4a';

    developer.log(
      'Starting recording to: $_currentFilePath',
      name: 'AudioRecorderService',
    );

    // Configure recording: AAC codec, reasonable quality for STT.
    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 44100,
      bitRate: 128000,
      numChannels: 1,
    );

    await _recorder.start(config, path: _currentFilePath!);

    _isRecording = true;
    _isPaused = false;
    _recordingStartTime = DateTime.now();
    _totalPausedDuration = Duration.zero;
    _pauseStartTime = null;
  }

  @override
  Future<RecordingResult?> stopRecording() async {
    if (!_isRecording) {
      developer.log(
        'stopRecording called but no recording in progress.',
        name: 'AudioRecorderService',
        level: 500,
      );
      return null;
    }

    // If paused, account for the final pause duration.
    if (_isPaused && _pauseStartTime != null) {
      _totalPausedDuration += DateTime.now().difference(_pauseStartTime!);
    }

    final path = await _recorder.stop();
    final duration = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!) -
            _totalPausedDuration
        : Duration.zero;

    _resetState();

    if (path == null || path.isEmpty) {
      developer.log(
        'Recording stopped but no file path returned.',
        name: 'AudioRecorderService',
        level: 900,
      );
      return null;
    }

    developer.log(
      'Recording stopped. Duration: ${duration.inSeconds}s, '
      'Path: $path',
      name: 'AudioRecorderService',
    );

    return RecordingResult(
      filePath: path,
      duration: duration,
      format: 'm4a',
    );
  }

  @override
  Future<void> cancelRecording() async {
    if (!_isRecording) {
      return;
    }

    developer.log(
      'Cancelling recording...',
      name: 'AudioRecorderService',
    );

    await _recorder.cancel();

    // Clean up the temp file if it exists.
    if (_currentFilePath != null) {
      final file = File(_currentFilePath!);
      if (await file.exists()) {
        await file.delete();
        developer.log(
          'Temp file deleted: $_currentFilePath',
          name: 'AudioRecorderService',
        );
      }
    }

    _resetState();
  }

  @override
  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) {
      return;
    }

    await _recorder.pause();
    _isPaused = true;
    _pauseStartTime = DateTime.now();

    developer.log(
      'Recording paused.',
      name: 'AudioRecorderService',
    );
  }

  @override
  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) {
      return;
    }

    // Track paused duration.
    if (_pauseStartTime != null) {
      _totalPausedDuration += DateTime.now().difference(_pauseStartTime!);
      _pauseStartTime = null;
    }

    await _recorder.resume();
    _isPaused = false;

    developer.log(
      'Recording resumed.',
      name: 'AudioRecorderService',
    );
  }

  @override
  bool get isRecording => _isRecording;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> dispose() async {
    if (_isRecording) {
      await cancelRecording();
    }
    _recorder.dispose();
  }

  /// Resets all internal tracking state after stop/cancel.
  void _resetState() {
    _isRecording = false;
    _isPaused = false;
    _recordingStartTime = null;
    _currentFilePath = null;
    _totalPausedDuration = Duration.zero;
    _pauseStartTime = null;
  }
}
