import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/vocabulary_category_entity.dart';

abstract class VocabularyCategoryRepository {
  Future<Either<Failure, List<VocabularyCategoryEntity>>> getCategories();
  Future<Either<Failure, VocabularyCategoryEntity>> createCategory(String name);
  Future<Either<Failure, VocabularyCategoryEntity>> updateCategory(int id, String name);
  Future<Either<Failure, void>> deleteCategory(int id);
}
