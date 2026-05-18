import 'package:equatable/equatable.dart';
import '../../domain/entities/vocabulary_category_entity.dart';

sealed class VocabularyCategoryState extends Equatable {
  const VocabularyCategoryState();

  @override
  List<Object?> get props => [];
}

class VocabularyCategoryInitial extends VocabularyCategoryState {}

class VocabularyCategoryLoading extends VocabularyCategoryState {}

class VocabularyCategoryLoaded extends VocabularyCategoryState {
  final List<VocabularyCategoryEntity> categories;

  const VocabularyCategoryLoaded(this.categories);

  @override
  List<Object?> get props => [categories];
}

class VocabularyCategoryError extends VocabularyCategoryState {
  final String message;

  const VocabularyCategoryError(this.message);

  @override
  List<Object?> get props => [message];
}
