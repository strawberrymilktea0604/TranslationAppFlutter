import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/features/translation/domain/entities/translation_entity.dart';

/// State for TranslationCubit following Bloc naming conventions.
/// Uses sealed class approach for type-safe exhaustive switch.
@immutable
sealed class TranslationState extends Equatable {
  const TranslationState();
}

/// Initial state — no translation has been requested yet.
final class TranslationInitial extends TranslationState {
  const TranslationInitial();

  @override
  List<Object?> get props => [];
}

/// Loading state — translation is in progress.
final class TranslationInProgress extends TranslationState {
  const TranslationInProgress();

  @override
  List<Object?> get props => [];
}

/// Success state — translation completed successfully.
final class TranslationSuccess extends TranslationState {
  final TranslationEntity translation;

  const TranslationSuccess(this.translation);

  @override
  List<Object?> get props => [translation];
}

/// Failure state — translation failed with an error message.
final class TranslationFailure extends TranslationState {
  final String message;

  const TranslationFailure(this.message);

  @override
  List<Object?> get props => [message];
}
