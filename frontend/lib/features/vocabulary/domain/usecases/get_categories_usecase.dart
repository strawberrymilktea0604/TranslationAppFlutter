import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/vocabulary_category_entity.dart';
import '../repositories/vocabulary_category_repository.dart';

class GetCategoriesUseCase {
  final VocabularyCategoryRepository repository;

  GetCategoriesUseCase(this.repository);

  Future<Either<Failure, List<VocabularyCategoryEntity>>> call() async {
    return await repository.getCategories();
  }
}
