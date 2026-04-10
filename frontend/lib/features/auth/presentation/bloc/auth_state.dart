import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/features/auth/domain/entities/user_entity.dart';

/// Sealed state for AuthCubit.
@immutable
sealed class AuthState extends Equatable {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();

  @override
  List<Object?> get props => [];
}

final class AuthInProgress extends AuthState {
  const AuthInProgress();

  @override
  List<Object?> get props => [];
}

final class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();

  @override
  List<Object?> get props => [];
}

final class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}
