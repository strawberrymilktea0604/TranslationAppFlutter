import 'package:equatable/equatable.dart';

/// Base failure class used with `Either<Failure, T>`
/// from the dartz package. All failures extend this class.
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Failure returned when a server request fails.
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure(super.message, {this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

/// Failure returned when there is no network connectivity.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

/// Failure returned when local cache operations fail.
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Failure returned when authentication fails.
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Failure returned when input validation fails.
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure(super.message, {this.fieldErrors});

  @override
  List<Object?> get props => [message, fieldErrors];
}
