import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/vocabulary_category_repository.dart';

class DeleteCategoryUseCase {
  final VocabularyCategoryRepository repository;

  DeleteCategoryUseCase(this.repository);

  Future<Either<Failure, void>> call(int id) async {
    return await repository.deleteCategory(id);
  }
}
