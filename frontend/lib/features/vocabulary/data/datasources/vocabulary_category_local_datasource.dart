import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_database.dart';
import '../models/vocabulary_category_model.dart';

abstract class VocabularyCategoryLocalDataSource {
  Future<List<VocabularyCategoryModel>> getCategories();
  Future<VocabularyCategoryModel?> getCategoryById(int backendId);
  Future<void> saveCategory(VocabularyCategoryModel category);
  Future<void> deleteCategory(int backendId);
  Future<void> saveCategories(List<VocabularyCategoryModel> categories);
}

class VocabularyCategoryLocalDataSourceImpl implements VocabularyCategoryLocalDataSource {
  final IsarDatabase database;
  Isar get isar => database.isar;

  VocabularyCategoryLocalDataSourceImpl({required this.database});

  @override
  Future<List<VocabularyCategoryModel>> getCategories() async {
    return await isar.vocabularyCategoryModels.where().filter().isDeletedEqualTo(false).findAll();
  }
  
  @override
  Future<VocabularyCategoryModel?> getCategoryById(int backendId) async {
    return await isar.vocabularyCategoryModels.filter().backendIdEqualTo(backendId).isDeletedEqualTo(false).findFirst();
  }

  @override
  Future<void> saveCategory(VocabularyCategoryModel category) async {
    await isar.writeTxn(() async {
      final existing = await isar.vocabularyCategoryModels.filter().backendIdEqualTo(category.backendId).findFirst();
      if (existing != null) {
        category.id = existing.id;
      }
      await isar.vocabularyCategoryModels.put(category);
    });
  }
  
  @override
  Future<void> saveCategories(List<VocabularyCategoryModel> categories) async {
    await isar.writeTxn(() async {
      for (final category in categories) {
        final existing = await isar.vocabularyCategoryModels.filter().backendIdEqualTo(category.backendId).findFirst();
        if (existing != null) {
          category.id = existing.id;
        }
      }
      await isar.vocabularyCategoryModels.putAll(categories);
    });
  }

  @override
  Future<void> deleteCategory(int backendId) async {
    await isar.writeTxn(() async {
      final category = await isar.vocabularyCategoryModels.filter().backendIdEqualTo(backendId).findFirst();
      if (category != null) {
        category.isDeleted = true;
        await isar.vocabularyCategoryModels.put(category);
      }
    });
  }
}
