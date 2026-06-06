import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/app_error_message.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/create_category_usecase.dart';
import '../../domain/usecases/update_category_usecase.dart';
import '../../domain/usecases/delete_category_usecase.dart';
import 'vocabulary_category_state.dart';

class VocabularyCategoryCubit extends Cubit<VocabularyCategoryState> {
  final GetCategoriesUseCase _getCategoriesUseCase;
  final CreateCategoryUseCase _createCategoryUseCase;
  final UpdateCategoryUseCase _updateCategoryUseCase;
  final DeleteCategoryUseCase _deleteCategoryUseCase;

  VocabularyCategoryCubit({
    required GetCategoriesUseCase getCategoriesUseCase,
    required CreateCategoryUseCase createCategoryUseCase,
    required UpdateCategoryUseCase updateCategoryUseCase,
    required DeleteCategoryUseCase deleteCategoryUseCase,
  }) : _getCategoriesUseCase = getCategoriesUseCase,
       _createCategoryUseCase = createCategoryUseCase,
       _updateCategoryUseCase = updateCategoryUseCase,
       _deleteCategoryUseCase = deleteCategoryUseCase,
       super(VocabularyCategoryInitial());

  Future<void> loadCategories() async {
    if (isClosed) return;
    emit(VocabularyCategoryLoading());

    final result = await _getCategoriesUseCase();
    if (isClosed) return;

    result.fold(
      (failure) => emit(VocabularyCategoryError(AppErrorMessage.fromFailure(failure))),
      (categories) => emit(VocabularyCategoryLoaded(categories)),
    );
  }

  Future<void> createCategory(String name) async {
    final result = await _createCategoryUseCase(name);
    if (isClosed) return;

    result.fold(
      (failure) => emit(VocabularyCategoryError(AppErrorMessage.fromFailure(failure))),
      (_) => loadCategories(),
    );
  }

  Future<void> updateCategory(int id, String name) async {
    final result = await _updateCategoryUseCase(id, name);
    if (isClosed) return;

    result.fold(
      (failure) => emit(VocabularyCategoryError(AppErrorMessage.fromFailure(failure))),
      (_) => loadCategories(),
    );
  }

  Future<void> deleteCategory(int id) async {
    final result = await _deleteCategoryUseCase(id);
    if (isClosed) return;

    result.fold(
      (failure) => emit(VocabularyCategoryError(AppErrorMessage.fromFailure(failure))),
      (_) => loadCategories(),
    );
  }
}
