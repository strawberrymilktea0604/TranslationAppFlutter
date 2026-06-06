import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_error_message.dart';
import '../../domain/usecases/save_vocabulary_usecase.dart';
import '../../domain/usecases/get_vocabulary_list_usecase.dart';
import '../../domain/usecases/delete_vocabulary_usecase.dart';
import '../../../../injection_container.dart';
import '../../../sync/presentation/bloc/sync_cubit.dart';
import 'vocabulary_state.dart';

/// Manages vocabulary state.
///
/// Flow: UI → Cubit → UseCase → Repository → DataSource (Isar).
///
/// Offline-first behavior:
/// - [saveVocabulary] saves to Isar with isSynced=false,
///   then emits [VocabularySaveSuccess] immediately.
/// - [loadVocabularyList] reads from Isar (local-first).
/// - [deleteVocabulary] soft-deletes in Isar with
///   isDeleted=true, isSynced=false.
class VocabularyCubit extends Cubit<VocabularyState> {
  final SaveVocabularyUseCase _saveVocabularyUseCase;
  final GetVocabularyListUseCase _getVocabularyListUseCase;
  final DeleteVocabularyUseCase _deleteVocabularyUseCase;

  VocabularyCubit({
    required SaveVocabularyUseCase saveVocabularyUseCase,
    required GetVocabularyListUseCase getVocabularyListUseCase,
    required DeleteVocabularyUseCase deleteVocabularyUseCase,
  }) : _saveVocabularyUseCase = saveVocabularyUseCase,
       _getVocabularyListUseCase = getVocabularyListUseCase,
       _deleteVocabularyUseCase = deleteVocabularyUseCase,
       super(const VocabularyInitial());

  /// Saves a vocabulary entry to local Isar DB.
  ///
  /// Emits: [VocabularySaving] → [VocabularySaveSuccess] or [VocabularyFailure].
  /// The entry is saved with isSynced=false for later sync.
  Future<void> saveVocabulary({
    required String word,
    required String translation,
    required String sourceLanguage,
    required String targetLanguage,
    String category = 'Chưa phân loại',
    int? categoryId,
  }) async {
    if (isClosed) return;
    emit(const VocabularySaving());

    final result = await _saveVocabularyUseCase(
      SaveVocabularyParams(
        word: word,
        translation: translation,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        category: category,
        categoryId: categoryId,
      ),
    );
    if (isClosed) return;

    result.fold((failure) => emit(VocabularyFailure(AppErrorMessage.fromFailure(failure))), (
      entity,
    ) {
      emit(VocabularySaveSuccess(entity));
      // Trigger background sync immediately if online
      try {
        sl<SyncCubit>().requestSync();
      } catch (_) {}
    });
  }

  /// Loads the vocabulary list from local Isar DB.
  ///
  /// Emits: [VocabularyLoading] → [VocabularyLoaded] or [VocabularyFailure].
  Future<void> loadVocabularyList({
    String? searchQuery,
    String? category,
  }) async {
    if (isClosed) return;
    emit(const VocabularyLoading());

    final result = await _getVocabularyListUseCase(
      GetVocabularyListParams(searchQuery: searchQuery, category: category),
    );
    if (isClosed) return;

    result.fold(
      (failure) => emit(VocabularyFailure(AppErrorMessage.fromFailure(failure))),
      (list) => emit(VocabularyLoaded(list)),
    );
  }

  /// Soft-deletes a vocabulary entry in local Isar DB.
  ///
  /// Emits: [VocabularyLoading] → [VocabularyDeleteSuccess] or [VocabularyFailure].
  Future<void> deleteVocabulary(int isarId) async {
    if (isClosed) return;
    emit(const VocabularyLoading());

    final result = await _deleteVocabularyUseCase(
      DeleteVocabularyParams(isarId: isarId),
    );
    if (isClosed) return;

    result.fold((failure) => emit(VocabularyFailure(AppErrorMessage.fromFailure(failure))), (_) {
      emit(const VocabularyDeleteSuccess());
      // Trigger background sync immediately if online
      try {
        sl<SyncCubit>().requestSync();
      } catch (_) {}
    });
  }
}
