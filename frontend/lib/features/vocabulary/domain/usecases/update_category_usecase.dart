import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/vocabulary_category_entity.dart';
import '../repositories/vocabulary_category_repository.dart';

class UpdateCategoryUseCase {
  final VocabularyCategoryRepository repository;

  UpdateCategoryUseCase(this.repository);

  Future<Either<Failure, VocabularyCategoryEntity>> call(int id, String name) async {
    return await repository.updateCategory(id, name);
  }
}
