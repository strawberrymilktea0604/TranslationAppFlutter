import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/translation/domain/usecases/translate_text_usecase.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_state.dart';

/// Manages state for the translation feature.
/// Flow: UI → Cubit → UseCase → Repository → DataSource.
class TranslationCubit extends Cubit<TranslationState> {
  final TranslateTextUseCase _translateTextUseCase;

  TranslationCubit(this._translateTextUseCase)
    : super(const TranslationInitial());

  /// Translates text and emits Loading → Success or Failure.
  Future<void> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    emit(const TranslationInProgress());

    final result = await _translateTextUseCase(
      TranslateTextParams(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      ),
    );

    result.fold(
      (failure) => emit(TranslationFailure(failure.message)),
      (translation) => emit(TranslationSuccess(translation)),
    );
  }

  /// Resets to initial state (clears result without animation).
  void reset() => emit(const TranslationInitial());
}
