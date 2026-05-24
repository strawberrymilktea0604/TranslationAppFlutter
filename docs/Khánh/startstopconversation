# Start/Stop Conversation Implementation Plan

This plan details the steps to implement the start and stop actions for the conversation feature, integrating WebSocket session management with real-time audio streaming from the device microphone.

## User Review Required

> [!IMPORTANT]
> To stream binary audio chunks to the backend in real-time, the `AudioRecorderService` needs to be extended to support streaming (using `record` package's `startStream` method), as the current implementation only supports recording to a file. 

## Open Questions

None at this moment.

## Proposed Changes

### Core Audio Recorder Service
Extending the audio recorder service to support raw PCM stream output.

#### [MODIFY] [audio_recorder_service.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/core/audio_recorder/audio_recorder_service.dart)
- Add `Future<Stream<Uint8List>> startStreamRecording()` to the abstract class.
- Add `Future<void> stopStreamRecording()` to the abstract class.
- Implement these methods in `AudioRecorderServiceImpl` using `_recorder.startStream(config)`. The config should output raw PCM data (`AudioEncoder.pcm16bits` if supported, or matching the backend's expected `pcm_s16le` format with 16000Hz sample rate).

### Conversation Feature
Integrating the audio stream with the WebSocket client.

#### [MODIFY] [conversation_cubit.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/bloc/conversation_cubit.dart)
- **Dependency Injection**: Add `AudioRecorderService` to the constructor.
- **State variables**: Add `StreamSubscription<Uint8List>? _audioSubscription`.
- **Start Session**: When `startSession` or `startListening` is triggered, start the audio stream and listen to it. In the listener, pipe the chunks to `_repository.sendAudioChunk(chunk)`.
- **Stop Session**: When `stopListening` is called, stop the audio stream, cancel the subscription, and call `_repository.endUtterance()`.
- **Disconnect**: On `disconnect()` or `endSession()`, ensure the recorder is stopped, subscription is cancelled, WebSocket is closed, and the UI resets to the initial state.

#### [MODIFY] [injection_container.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/injection_container.dart)
- Update the factory registration for `ConversationCubit` to inject `sl<AudioRecorderService>()`.

## Verification Plan

### Automated/Manual Testing
- Run `flutter analyze` to ensure no syntax or typing errors.
- Ensure the Flutter app builds successfully.
- Trigger `startListening` in the UI (or manually call it) and verify that microphone permissions are requested, the WebSocket receives the metadata, and binary frames are sent.
- Trigger `stopListening` and verify the WebSocket receives `end_utterance` and the microphone turns off.
- Disconnect and ensure all connections are closed cleanly.
