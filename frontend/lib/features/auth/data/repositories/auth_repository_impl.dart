import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/core/utils/jwt_decoder.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:frontend/features/auth/domain/entities/user_entity.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';

/// Implementation of [AuthRepository] following Clean Architecture.
///
/// Orchestrates [AuthRemoteDataSource] (API calls) and
/// [AuthLocalDataSource] (secure token storage).
/// Catches all exceptions and converts them to [Failure] objects
/// so the domain/presentation layers never deal with raw exceptions.
/// Reference: copilot-instructions.md §3.2
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;

  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource,
       _networkInfo = networkInfo;

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      // 1. Call BE login API.
      final tokenModel = await _remoteDataSource.login(
        email: email,
        password: password,
      );

      // 2. Decode JWT to extract user ID.
      final userId = JwtDecoder.getUserId(tokenModel.accessToken);
      if (userId == null) {
        return const Left(AuthFailure('Invalid token received from server'));
      }

      // 3. Store tokens securely (flutter_secure_storage).
      await _localDataSource.saveTokens(
        accessToken: tokenModel.accessToken,
        refreshToken: tokenModel.refreshToken,
      );

      // 4. Cache user data alongside tokens.
      await _localDataSource.saveUserData(userId: userId, email: email);

      // 5. Return UserEntity to the domain layer.
      return Right(
        UserEntity(id: userId, email: email, createdAt: DateTime.now()),
      );
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> checkEmail(String email) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }
    try {
      final isAvailable = await _remoteDataSource.checkEmail(email: email);
      return Right(isAvailable);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      // 1. Call BE register API.
      final tokenModel = await _remoteDataSource.register(
        email: email,
        firstName: firstName,
        lastName: lastName,
        password: password,
      );

      // 2. Decode JWT to extract user ID.
      final userId = JwtDecoder.getUserId(tokenModel.accessToken);
      if (userId == null) {
        return const Left(AuthFailure('Invalid token received from server'));
      }

      // 3. Store tokens securely (flutter_secure_storage).
      await _localDataSource.saveTokens(
        accessToken: tokenModel.accessToken,
        refreshToken: tokenModel.refreshToken,
      );

      // 4. Cache user data with name for local display.
      await _localDataSource.saveUserData(
        userId: userId,
        email: email,
        name: '$firstName $lastName'.trim(),
      );

      // 5. Return UserEntity to the domain layer.
      return Right(
        UserEntity(
          id: userId,
          email: email,
          name: '$firstName $lastName'.trim(),
          createdAt: DateTime.now(),
        ),
      );
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      // 1. Read stored tokens for backend revocation.
      final accessToken = await _localDataSource.getAccessToken();
      final refreshTokenValue = await _localDataSource.getRefreshToken();

      // 2. Best-effort: try to revoke tokens on the server.
      //    Even if the BE call fails, we MUST clear local tokens.
      if (accessToken != null && refreshTokenValue != null) {
        try {
          if (await _networkInfo.isConnected) {
            await _remoteDataSource.logout(
              accessToken: accessToken,
              refreshToken: refreshTokenValue,
            );
          }
        } catch (_) {
          // Ignore remote logout errors.
          // Local token cleanup is the priority.
        }
      }

      // 3. ALWAYS clear local tokens on logout (critical).
      await _localDataSource.clearAll();

      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      // Still try to clear even on unexpected errors.
      try {
        await _localDataSource.clearAll();
      } catch (_) {}
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      // 1. Check if tokens exist in secure storage.
      final hasTokens = await _localDataSource.hasTokens();
      if (!hasTokens) {
        return const Left(AuthFailure('No authenticated session'));
      }

      // 2. Check access token validity.
      final accessToken = await _localDataSource.getAccessToken();
      if (accessToken == null) {
        return const Left(AuthFailure('No access token found'));
      }

      // 3. If token is expired, try to refresh.
      if (JwtDecoder.isExpired(accessToken)) {
        final refreshResult = await refreshToken();
        if (refreshResult.isLeft()) {
          // Refresh failed — user must re-login.
          await _localDataSource.clearAll();
          return const Left(AuthFailure('Session expired, please login again'));
        }
      }

      // 4. Read cached user data.
      final userData = await _localDataSource.getUserData();
      if (userData == null || userData['userId'] == null) {
        return const Left(AuthFailure('No user data found'));
      }

      return Right(
        UserEntity(
          id: userData['userId']!,
          email: userData['email'] ?? '',
          name: userData['name'],
          role: userData['role'] ?? 'user',
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> refreshToken() async {
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      // 1. Get stored refresh token.
      final refreshTokenValue = await _localDataSource.getRefreshToken();
      if (refreshTokenValue == null) {
        return const Left(AuthFailure('No refresh token available'));
      }

      // 2. Call BE refresh endpoint.
      final newTokens = await _remoteDataSource.refreshToken(
        refreshToken: refreshTokenValue,
      );

      // 3. Save new tokens (replacing old ones).
      await _localDataSource.saveTokens(
        accessToken: newTokens.accessToken,
        refreshToken: newTokens.refreshToken,
      );

      return const Right(null);
    } on AuthException catch (e) {
      // Refresh token is invalid/revoked — clear everything.
      await _localDataSource.clearAll();
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
