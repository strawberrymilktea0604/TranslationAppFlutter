import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:frontend/features/auth/domain/entities/user_entity.dart';

/// Sealed state for AuthCubit.
@immutable
sealed class AuthState extends Equatable {
  const AuthState();
}

/// Initial state — auth status hasn't been checked yet.
final class AuthInitial extends AuthState {
  const AuthInitial();

  @override
  List<Object?> get props => [];
}

/// An authentication operation is in progress
/// (login, register, logout, or auto-login check).
final class AuthInProgress extends AuthState {
  const AuthInProgress();

  @override
  List<Object?> get props => [];
}

/// User is authenticated. Contains the [UserEntity] data.
final class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// User is not authenticated (logged out or session expired).
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();

  @override
  List<Object?> get props => [];
}

/// An authentication operation failed.
/// Named [AuthFailureState] to avoid conflict with
/// [Failure] from core/error/failures.dart.
final class AuthFailureState extends AuthState {
  final String message;

  const AuthFailureState(this.message);

  @override
  List<Object?> get props => [message];
}
