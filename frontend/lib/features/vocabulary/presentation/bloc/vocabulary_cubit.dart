import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/save_vocabulary_usecase.dart';
import '../../domain/usecases/get_vocabulary_list_usecase.dart';
import '../../domain/usecases/delete_vocabulary_usecase.dart';
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
  })  : _saveVocabularyUseCase = saveVocabularyUseCase,
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
  }) async {
    emit(const VocabularySaving());

    final result = await _saveVocabularyUseCase(
      SaveVocabularyParams(
        word: word,
        translation: translation,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      ),
    );

    result.fold(
      (failure) => emit(VocabularyFailure(failure.message)),
      (entity) => emit(VocabularySaveSuccess(entity)),
    );
  }

  /// Loads the vocabulary list from local Isar DB.
  ///
  /// Emits: [VocabularyLoading] → [VocabularyLoaded] or [VocabularyFailure].
  Future<void> loadVocabularyList({
    String? searchQuery,
    String? category,
  }) async {
    emit(const VocabularyLoading());

    final result = await _getVocabularyListUseCase(
      GetVocabularyListParams(
        searchQuery: searchQuery,
        category: category,
      ),
    );

    result.fold(
      (failure) => emit(VocabularyFailure(failure.message)),
      (list) => emit(VocabularyLoaded(list)),
    );
  }

  /// Soft-deletes a vocabulary entry in local Isar DB.
  ///
  /// Emits: [VocabularyLoading] → [VocabularyDeleteSuccess] or [VocabularyFailure].
  Future<void> deleteVocabulary(String id) async {
    emit(const VocabularyLoading());

    final result = await _deleteVocabularyUseCase(
      DeleteVocabularyParams(id: id),
    );

    result.fold(
      (failure) => emit(VocabularyFailure(failure.message)),
      (_) => emit(const VocabularyDeleteSuccess()),
    );
  }
}
