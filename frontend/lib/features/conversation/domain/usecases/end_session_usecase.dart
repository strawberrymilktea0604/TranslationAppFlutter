import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';

/// UseCase that ends the current conversation session gracefully.
///
/// Sends `session_end` to the backend, which flushes any remaining
/// audio and cleans up server-side state.
///
/// Clean Architecture flow:
///   ConversationViewModel → EndSessionUseCase → ConversationRepository
class EndSessionUseCase {
  final ConversationRepository _repository;

  const EndSessionUseCase(this._repository);

  /// Signals the server to end the current session.
  void call() {
    _repository.endSession();
  }
}
