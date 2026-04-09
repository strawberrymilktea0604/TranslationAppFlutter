import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/domain/usecases/login_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/register_usecase.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';

/// AuthCubit manages authentication state.
/// Global ReadCubit — provided at app.dart level.
class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;

  AuthCubit({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        super(const AuthInitial());

  /// Logs in the user.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    emit(const AuthInProgress());

    final result = await _loginUseCase(
      LoginParams(email: email, password: password),
    );

    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  /// Registers a new user.
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
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  /// Logs out the user.
  void logout() {
    emit(const AuthUnauthenticated());
  }
}
