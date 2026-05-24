import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';
import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';

/// Parameters for [ConnectConversationUseCase].
class ConnectConversationParams {
  /// JWT access token for WebSocket authentication.
  final String accessToken;

  const ConnectConversationParams({required this.accessToken});
}

/// UseCase that establishes a WebSocket connection for the conversation
/// and returns a stream of [ConversationEvent]s.
///
/// Clean Architecture flow:
///   UI → ConversationCubit → ConnectConversationUseCase → ConversationRepository
///
/// This use case orchestrates the connection setup. The Cubit is
/// responsible for listening to the returned stream and emitting
/// appropriate states.
class ConnectConversationUseCase {
  final ConversationRepository _repository;

  const ConnectConversationUseCase(this._repository);

  /// Connects to the conversation WebSocket.
  ///
  /// Returns [Right] with the event stream on success,
  /// or [Left] with a [Failure] if connection fails.
  Either<Failure, Stream<ConversationEvent>> call(
    ConnectConversationParams params,
  ) {
    try {
      final stream = _repository.connect(params.accessToken);
      return Right(stream);
    } on Exception catch (e) {
      return Left(ServerFailure('Failed to connect: $e'));
    }
  }
}
