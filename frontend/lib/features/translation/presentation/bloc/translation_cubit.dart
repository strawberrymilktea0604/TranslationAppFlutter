import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/translation/domain/usecases/translate_text_usecase.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_state.dart';
import 'package:frontend/features/history/domain/entities/history_entity.dart' as frontend_history;
import 'package:frontend/features/history/domain/repositories/history_repository.dart' as frontend_history;
import 'package:frontend/injection_container.dart';

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
      (translation) {
        // Lưu lịch sử offline sau khi dịch thành công
        try {
          final historyEntity = frontend_history.HistoryEntity(
            isarId: 0,
            id: 'local_${DateTime.now().millisecondsSinceEpoch}',
            sourceText: translation.sourceText,
            translatedText: translation.translatedText,
            sourceLanguage: translation.sourceLanguage,
            targetLanguage: translation.targetLanguage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isSynced: false,
          );
          sl<frontend_history.HistoryRepository>().saveHistory(historyEntity);
        } catch (_) {}
        
        emit(TranslationSuccess(translation));
      },
    );
  }

  /// Resets to initial state (clears result without animation).
  void reset() => emit(const TranslationInitial());
}
