import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/login_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/register_usecase.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';

/// AuthCubit manages authentication state.
/// Global ReadCubit — provided at app.dart level.
///
/// Follows the flow: UI → Cubit → UseCase → Repository → DataSource.
/// Business logic is delegated to UseCases; this Cubit only
/// orchestrates state transitions.
class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;

  AuthCubit({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _logoutUseCase = logoutUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        super(const AuthInitial());

  /// Checks if the user has a valid session on app startup.
  ///
  /// Reads tokens from flutter_secure_storage and attempts
  /// a silent refresh if the access token is expired.
  /// Emits [AuthAuthenticated] if valid, [AuthUnauthenticated] otherwise.
  Future<void> checkAuthStatus() async {
    emit(const AuthInProgress());

    final result = await _getCurrentUserUseCase(const NoParams());

    result.fold(
      (_) => emit(const AuthUnauthenticated()),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  /// Logs in the user with email and password.
  ///
  /// Calls the BE login API, stores tokens in flutter_secure_storage,
  /// and emits [AuthAuthenticated] on success.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    emit(const AuthInProgress());

    final result = await _loginUseCase(
      LoginParams(email: email, password: password),
    );

    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  /// Registers a new user.
  ///
  /// Calls the BE register API, stores tokens in flutter_secure_storage,
  /// and emits [AuthAuthenticated] on success.
  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    emit(const AuthInProgress());

    final result = await _registerUseCase(
      RegisterParams(email: email, password: password, name: name),
    );

    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  /// Logs out the user.
  ///
  /// Revokes tokens on the backend (best-effort) and
  /// clears all tokens from flutter_secure_storage.
  /// Always transitions to [AuthUnauthenticated] regardless
  /// of whether the remote logout succeeds.
  Future<void> logout() async {
    emit(const AuthInProgress());

    await _logoutUseCase(const NoParams());

    // Always emit unauthenticated after logout attempt.
    // Local tokens are cleared even if remote logout fails.
    emit(const AuthUnauthenticated());
  }
}
