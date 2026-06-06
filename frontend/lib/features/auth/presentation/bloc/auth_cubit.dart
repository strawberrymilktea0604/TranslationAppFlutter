import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/error/app_error_message.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/login_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/register_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/check_email_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/update_profile_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/change_password_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/upload_avatar_usecase.dart';
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
  final CheckEmailUseCase _checkEmailUseCase;
  final UpdateProfileUseCase _updateProfileUseCase;
  final ChangePasswordUseCase _changePasswordUseCase;
  final UploadAvatarUseCase _uploadAvatarUseCase;

  AuthCubit({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required CheckEmailUseCase checkEmailUseCase,
    required UpdateProfileUseCase updateProfileUseCase,
    required ChangePasswordUseCase changePasswordUseCase,
    required UploadAvatarUseCase uploadAvatarUseCase,
  }) : _loginUseCase = loginUseCase,
       _registerUseCase = registerUseCase,
       _logoutUseCase = logoutUseCase,
       _getCurrentUserUseCase = getCurrentUserUseCase,
       _checkEmailUseCase = checkEmailUseCase,
       _updateProfileUseCase = updateProfileUseCase,
       _changePasswordUseCase = changePasswordUseCase,
       _uploadAvatarUseCase = uploadAvatarUseCase,
       super(const AuthInitial());

  /// Checks if the user has a valid session on app startup.
  ///
  /// Reads tokens from flutter_secure_storage and attempts
  /// a silent refresh if the access token is expired.
  /// Emits [AuthAuthenticated] if valid, [AuthUnauthenticated] otherwise.
  Future<void> checkAuthStatus({bool isAdminApp = false}) async {
    emit(const AuthInProgress());

    final result = await _getCurrentUserUseCase(const NoParams());

    result.fold(
      (_) => emit(const AuthUnauthenticated()),
      (user) {
        if (user.status == 'locked') {
          _logoutUseCase(const NoParams());
          emit(const AuthUnauthenticated());
        } else if (user.role == 'admin' && !isAdminApp) {
          _logoutUseCase(const NoParams());
          emit(const AuthUnauthenticated());
        } else if (user.role != 'admin' && isAdminApp) {
          _logoutUseCase(const NoParams());
          emit(const AuthUnauthenticated());
        } else {
          emit(AuthAuthenticated(user));
        }
      },
    );
  }

  /// Logs in the user with email and password.
  ///
  /// Calls the BE login API, stores tokens in flutter_secure_storage,
  /// and emits [AuthAuthenticated] on success.
  Future<void> login({required String email, required String password, bool isAdminApp = false}) async {
    emit(const AuthInProgress());

    final result = await _loginUseCase(
      LoginParams(email: email, password: password),
    );

    result.fold(
      (failure) => emit(AuthFailureState(AppErrorMessage.fromFailure(failure))),
      (user) {
        if (user.status == 'locked') {
          _logoutUseCase(const NoParams());
          emit(const AuthFailureState('Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản trị viên.'));
        } else if (user.role == 'admin' && !isAdminApp) {
          _logoutUseCase(const NoParams());
          emit(const AuthFailureState('Tài khoản admin không được phép đăng nhập trên ứng dụng này.'));
        } else if (user.role != 'admin' && isAdminApp) {
          _logoutUseCase(const NoParams());
          emit(const AuthFailureState('Chỉ có admin mới được phép đăng nhập vào dashboard.'));
        } else {
          emit(AuthAuthenticated(user));
        }
      },
    );
  }

  /// Registers a new user.
  ///
  /// Calls the BE register API, stores tokens in flutter_secure_storage,
  /// and emits [AuthAuthenticated] on success.
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    emit(const AuthInProgress());

    final result = await _registerUseCase(
      RegisterParams(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      ),
    );

    result.fold(
      (failure) => emit(AuthFailureState(AppErrorMessage.fromFailure(failure))),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  /// Checks if an email is available for registration.
  /// Returns null if available, or an error message if not.
  Future<String?> checkEmail(String email) async {
    final result = await _checkEmailUseCase(email);
    return result.fold(
      (failure) => AppErrorMessage.fromFailure(failure),
      (isAvailable) =>
          isAvailable ? null : 'Email is already registered. Please login.',
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

  /// Updates the user's profile without emitting AuthInProgress
  Future<void> updateProfile({String? firstName, String? lastName}) async {
    final result = await _updateProfileUseCase(UpdateProfileParams(
      firstName: firstName,
      lastName: lastName,
    ));

    result.fold(
      (failure) => throw Exception(AppErrorMessage.fromFailure(failure)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  /// Changes the user's password without emitting AuthInProgress
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    final result = await _changePasswordUseCase(ChangePasswordParams(
      oldPassword: oldPassword,
      newPassword: newPassword,
    ));

    if (result.isLeft()) {
      final failure = result.fold((l) => l, (r) => throw Exception('Unexpected Right'));
      throw Exception(AppErrorMessage.fromFailure(failure));
    }
  }

  /// Uploads user avatar without emitting AuthInProgress
  Future<void> uploadAvatar({required String filePath}) async {
    final result = await _uploadAvatarUseCase(UploadAvatarParams(
      filePath: filePath,
    ));

    result.fold(
      (failure) => throw Exception(AppErrorMessage.fromFailure(failure)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }
}
