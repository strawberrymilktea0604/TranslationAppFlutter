import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/audio_recorder/audio_recorder_service.dart';
import 'package:frontend/core/audio_recorder/bloc/recording_cubit.dart';
import 'package:frontend/core/audio_recorder/bloc/recording_state.dart';

void main() {
  group('RecordingCubit lifecycle', () {
    test('close cancels a paused recording', () async {
      final recorderService = _FakeAudioRecorderService();
      final cubit = RecordingCubit(recorderService: recorderService);

      await cubit.startRecording();
      await cubit.pauseRecording();

      expect(cubit.state, isA<RecordingPaused>());

      await cubit.close();

      expect(recorderService.cancelCallCount, 1);
      expect(recorderService.isRecording, isFalse);
      expect(recorderService.isPaused, isFalse);
    });
  });
}

class _FakeAudioRecorderService implements AudioRecorderService {
  int cancelCallCount = 0;

  @override
  bool isRecording = false;

  @override
  bool isPaused = false;

  @override
  Future<void> cancelRecording() async {
    cancelCallCount++;
    isRecording = false;
    isPaused = false;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> pauseRecording() async {
    isPaused = true;
  }

  @override
  Future<void> resumeRecording() async {
    isPaused = false;
  }

  @override
  Future<void> startRecording() async {
    isRecording = true;
  }

  @override
  Future<Stream<Uint8List>> startStreamRecording() {
    throw UnimplementedError();
  }

  @override
  Future<RecordingResult?> stopRecording() async {
    isRecording = false;
    isPaused = false;
    return const RecordingResult(
      filePath: 'recording.m4a',
      duration: Duration(seconds: 1),
      format: 'm4a',
    );
  }

  @override
  Future<void> stopStreamRecording() {
    throw UnimplementedError();
  }
}
