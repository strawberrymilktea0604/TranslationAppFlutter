import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/translation/domain/usecases/translate_text_usecase.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_state.dart';

/// TranslationCubit manages the state for text translation.
/// Follows the flow: UI → Cubit → UseCase → Repository → DataSource.
/// Emits Loading before async operations, then Success or Failure.
class TranslationCubit extends Cubit<TranslationState> {
  final TranslateTextUseCase _translateTextUseCase;

  TranslationCubit(this._translateTextUseCase)
      : super(const TranslationInitial());

  /// Translates text from source to target language.
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
}
