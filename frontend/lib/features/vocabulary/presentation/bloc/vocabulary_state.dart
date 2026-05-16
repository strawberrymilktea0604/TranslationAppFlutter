import 'package:equatable/equatable.dart';

import '../../domain/entities/vocabulary_entity.dart';

/// States for the VocabularyCubit.
///
/// State flow:
/// - Initial → Loading → Loaded / Failure
/// - Loaded → Saving → SaveSuccess → Loaded (refresh)
/// - Loaded → Deleting → DeleteSuccess → Loaded (refresh)
sealed class VocabularyState extends Equatable {
  const VocabularyState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any vocabulary data has been loaded.
class VocabularyInitial extends VocabularyState {
  const VocabularyInitial();
}

/// Loading the vocabulary list from local Isar DB.
class VocabularyLoading extends VocabularyState {
  const VocabularyLoading();
}

/// Successfully loaded the vocabulary list.
class VocabularyLoaded extends VocabularyState {
  final List<VocabularyEntity> vocabularyList;

  const VocabularyLoaded(this.vocabularyList);

  @override
  List<Object?> get props => [vocabularyList];
}

/// A vocabulary entry is being saved to local Isar DB.
class VocabularySaving extends VocabularyState {
  const VocabularySaving();
}

/// A vocabulary entry was saved successfully.
/// Contains the saved entity so the UI can display
/// a success message with the saved word.
class VocabularySaveSuccess extends VocabularyState {
  final VocabularyEntity savedEntry;

  const VocabularySaveSuccess(this.savedEntry);

  @override
  List<Object?> get props => [savedEntry];
}

/// A vocabulary entry was deleted successfully.
class VocabularyDeleteSuccess extends VocabularyState {
  const VocabularyDeleteSuccess();
}

/// An error occurred during a vocabulary operation.
class VocabularyFailure extends VocabularyState {
  final String message;

  const VocabularyFailure(this.message);

  @override
  List<Object?> get props => [message];
}
