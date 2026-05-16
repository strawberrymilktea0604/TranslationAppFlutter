import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/vocabulary_repository.dart';

/// Soft-deletes a vocabulary entry from local Isar DB.
/// Sets [isDeleted] = true and [isSynced] = false so the
/// deletion is synced to the server on next sync cycle.
class DeleteVocabularyUseCase extends UseCase<void, DeleteVocabularyParams> {
  final VocabularyRepository repository;

  DeleteVocabularyUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteVocabularyParams params) async {
    return await repository.deleteVocabulary(params.id);
  }
}

/// Parameters for [DeleteVocabularyUseCase].
class DeleteVocabularyParams extends Equatable {
  /// The Isar integer ID (as a string) of the entry to soft-delete.
  final String id;

  const DeleteVocabularyParams({required this.id});

  @override
  List<Object?> get props => [id];
}
