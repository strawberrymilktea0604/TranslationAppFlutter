import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/auth/domain/entities/user_entity.dart';

/// Abstract repository interface for authentication feature.
/// UC04 — Quản lý tài khoản.
abstract class AuthRepository {
  /// Logs in the user with email and password.
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });

  /// Registers a new user.
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  });

  /// Checks if an email is available for registration.
  Future<Either<Failure, bool>> checkEmail(String email);

  /// Logs out the current user.
  Future<Either<Failure, void>> logout();

  /// Gets the currently authenticated user.
  Future<Either<Failure, UserEntity>> getCurrentUser();

  /// Refreshes the access token using the refresh token.
  Future<Either<Failure, void>> refreshToken();
}
