import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/vocabulary/domain/entities/vocabulary_category_entity.dart';
import 'package:frontend/features/vocabulary/domain/repositories/vocabulary_category_repository.dart';
import 'package:frontend/features/vocabulary/domain/usecases/create_category_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/delete_category_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/get_categories_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/update_category_usecase.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_category_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_category_state.dart';

void main() {
  group('VocabularyCategoryCubit', () {
    test('loadCategories completes safely after cubit is closed', () async {
      final repository = _DelayedVocabularyCategoryRepository();
      final cubit = VocabularyCategoryCubit(
        getCategoriesUseCase: GetCategoriesUseCase(repository),
        createCategoryUseCase: CreateCategoryUseCase(repository),
        updateCategoryUseCase: UpdateCategoryUseCase(repository),
        deleteCategoryUseCase: DeleteCategoryUseCase(repository),
      );

      final loadFuture = cubit.loadCategories();

      expect(cubit.state, isA<VocabularyCategoryLoading>());

      await cubit.close();
      repository.completeCategories(const []);

      await expectLater(loadFuture, completes);
    });
  });
}

class _DelayedVocabularyCategoryRepository
    implements VocabularyCategoryRepository {
  final Completer<Either<Failure, List<VocabularyCategoryEntity>>>
  _categoriesCompleter = Completer();

  void completeCategories(List<VocabularyCategoryEntity> categories) {
    _categoriesCompleter.complete(Right(categories));
  }

  @override
  Future<Either<Failure, List<VocabularyCategoryEntity>>> getCategories() {
    return _categoriesCompleter.future;
  }

  @override
  Future<Either<Failure, VocabularyCategoryEntity>> createCategory(
    String name,
  ) async {
    return Right(
      VocabularyCategoryEntity(
        id: 1,
        name: name,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<Either<Failure, VocabularyCategoryEntity>> updateCategory(
    int id,
    String name,
  ) async {
    return Right(
      VocabularyCategoryEntity(
        id: id,
        name: name,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> deleteCategory(int id) async {
    return const Right(null);
  }
}
