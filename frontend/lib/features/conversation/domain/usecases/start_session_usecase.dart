import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';
import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';

/// Parameters for [StartSessionUseCase].
class StartSessionParams {
  /// Source language code (ISO 639-1), e.g. 'vi'.
  final String sourceLanguage;

  /// Target language code (ISO 639-1), e.g. 'en'.
  final String targetLanguage;

  /// Which speaker initiates the session.
  final ConversationSpeaker speaker;

  /// Audio sample rate in Hz (default: 16 000 for STT).
  final int sampleRate;

  /// Audio encoding format sent to the backend.
  final String audioFormat;

  const StartSessionParams({
    required this.sourceLanguage,
    required this.targetLanguage,
    this.speaker = ConversationSpeaker.speakerA,
    this.sampleRate = 16000,
    this.audioFormat = 'pcm_s16le',
  });
}

/// UseCase that starts a new conversation session on the backend.
///
/// Orchestrates two sequential WebSocket messages:
/// 1. `session_start` — creates a new session with language pair.
/// 2. `audio_metadata` — configures audio processing parameters.
///
/// Clean Architecture flow:
///   UI → ConversationViewModel → StartSessionUseCase → ConversationRepository
class StartSessionUseCase {
  final ConversationRepository _repository;

  const StartSessionUseCase(this._repository);

  /// Sends session_start and audio_metadata events to the server.
  void call(StartSessionParams params) {
    _repository.startSession(
      sourceLanguage: params.sourceLanguage,
      targetLanguage: params.targetLanguage,
      speaker: params.speaker,
    );

    _repository.sendAudioMetadata(
      sampleRate: params.sampleRate,
      audioFormat: params.audioFormat,
      speaker: params.speaker,
      sourceLanguage: params.sourceLanguage,
      targetLanguage: params.targetLanguage,
    );
  }
}
