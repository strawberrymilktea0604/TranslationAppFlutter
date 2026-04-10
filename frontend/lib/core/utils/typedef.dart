import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';

/// Type alias for `Either<Failure, T>` to reduce verbosity.
typedef ResultFuture<T> = Future<Either<Failure, T>>;

/// Type alias for `Either<Failure, void>`.
typedef ResultVoid = Future<Either<Failure, void>>;

/// Type alias for JSON map.
typedef DataMap = Map<String, dynamic>;
