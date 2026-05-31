import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';
import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';

/// UseCase that changes the active speaker in the current session.
///
/// Sends a `speaker_changed` event to the backend so subsequent
/// audio chunks are attributed to the correct speaker.
///
/// Clean Architecture flow:
///   ConversationViewModel → SwitchSpeakerUseCase → ConversationRepository
class SwitchSpeakerUseCase {
  final ConversationRepository _repository;

  const SwitchSpeakerUseCase(this._repository);

  /// Notifies the backend that the active speaker has changed.
  void call(ConversationSpeaker newSpeaker) {
    _repository.changeSpeaker(newSpeaker);
  }
}
