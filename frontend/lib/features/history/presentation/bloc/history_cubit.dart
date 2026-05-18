import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/features/history/domain/usecases/get_history_usecase.dart';
import 'package:frontend/core/usecases/usecase.dart';

import 'history_state.dart';

/// Manages translation history state (UC08).
///
/// Flow: UI → HistoryCubit → UseCase → Repository → DataSource (Isar).
///
/// Offline-first: all reads come from local Isar DB.
/// Writes are soft-deleted (isDeleted=true, isSynced=false).
class HistoryCubit extends Cubit<HistoryState> {
  final GetHistoryUseCase _getHistoryUseCase;
  final DeleteHistoryUseCase _deleteHistoryUseCase;
  final ClearHistoryUseCase _clearHistoryUseCase;

  HistoryCubit({
    required GetHistoryUseCase getHistoryUseCase,
    required DeleteHistoryUseCase deleteHistoryUseCase,
    required ClearHistoryUseCase clearHistoryUseCase,
  })  : _getHistoryUseCase = getHistoryUseCase,
        _deleteHistoryUseCase = deleteHistoryUseCase,
        _clearHistoryUseCase = clearHistoryUseCase,
        super(const HistoryInitial());

  /// Loads the history list from local Isar DB.
  ///
  /// Emits: [HistoryLoading] → [HistoryLoaded] or [HistoryFailure].
  Future<void> loadHistory({
    String? searchQuery,
    String? langFilter,
  }) async {
    emit(const HistoryLoading());

    final result = await _getHistoryUseCase(
      GetHistoryParams(
        searchQuery: searchQuery,
        langFilter: langFilter,
      ),
    );

    result.fold(
      (failure) => emit(HistoryFailure(failure.message)),
      (list) => emit(HistoryLoaded(list)),
    );
  }

  /// Soft-deletes a single history entry.
  ///
  /// Emits: [HistoryLoading] → [HistoryDeleteSuccess] or [HistoryFailure].
  Future<void> deleteHistory(int isarId) async {
    emit(const HistoryLoading());

    final result = await _deleteHistoryUseCase(
      DeleteHistoryParams(isarId: isarId),
    );

    result.fold(
      (failure) => emit(HistoryFailure(failure.message)),
      (_) => emit(const HistoryDeleteSuccess()),
    );
  }

  /// Soft-deletes all history entries.
  ///
  /// Emits: [HistoryLoading] → [HistoryClearSuccess] or [HistoryFailure].
  Future<void> clearHistory() async {
    emit(const HistoryLoading());

    final result = await _clearHistoryUseCase(const NoParams());

    result.fold(
      (failure) => emit(HistoryFailure(failure.message)),
      (_) => emit(const HistoryClearSuccess()),
    );
  }
}
