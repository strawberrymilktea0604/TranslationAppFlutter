import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend/core/error/failures.dart';

/// Abstract UseCase base class.
/// Every use case in the application should extend this class.
/// [T] is the return type on success.
/// [P] is the params type.
abstract class UseCase<T, P> {
  Future<Either<Failure, T>> call(P params);
}

/// Used when a UseCase does not require any parameters.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
