import 'package:equatable/equatable.dart';

import 'package:frontend/features/history/domain/entities/history_entity.dart';

/// States for [HistoryCubit].
///
/// State flow:
/// - Initial → Loading → Loaded / Failure
/// - Loaded  → Deleting → DeleteSuccess → (auto-reload → Loaded)
sealed class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => [];
}

/// Before any data has been fetched.
class HistoryInitial extends HistoryState {
  const HistoryInitial();
}

/// Loading history from local Isar DB.
class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

/// Successfully loaded the history list.
class HistoryLoaded extends HistoryState {
  final List<HistoryEntity> historyList;

  const HistoryLoaded(this.historyList);

  @override
  List<Object?> get props => [historyList];
}

/// A single history entry was deleted successfully.
class HistoryDeleteSuccess extends HistoryState {
  const HistoryDeleteSuccess();
}

/// All history was cleared.
class HistoryClearSuccess extends HistoryState {
  const HistoryClearSuccess();
}

/// An error occurred.
class HistoryFailure extends HistoryState {
  final String message;

  const HistoryFailure(this.message);

  @override
  List<Object?> get props => [message];
}
