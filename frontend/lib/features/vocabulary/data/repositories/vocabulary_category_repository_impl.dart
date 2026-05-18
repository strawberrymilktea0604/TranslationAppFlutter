import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../auth/data/datasources/auth_local_datasource.dart';
import '../../domain/entities/vocabulary_category_entity.dart';
import '../../domain/repositories/vocabulary_category_repository.dart';
import '../datasources/vocabulary_category_local_datasource.dart';
import '../datasources/vocabulary_category_remote_datasource.dart';
import '../models/vocabulary_category_model.dart';

class VocabularyCategoryRepositoryImpl implements VocabularyCategoryRepository {
  final VocabularyCategoryLocalDataSource localDataSource;
  final VocabularyCategoryRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final AuthLocalDataSource authLocalDataSource;

  VocabularyCategoryRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.networkInfo,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, List<VocabularyCategoryEntity>>> getCategories() async {
    try {
      if (await networkInfo.isConnected) {
        final token = await authLocalDataSource.getAccessToken();
        if (token != null) {
          try {
            final remoteCategories = await remoteDataSource.getCategories(token);
            await localDataSource.saveCategories(remoteCategories);
          } catch (e) {
            // Ignore fetch error, fallback to local
          }
        }
      }
      final localCategories = await localDataSource.getCategories();
      return Right(localCategories.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, VocabularyCategoryEntity>> createCategory(String name) async {
    try {
      if (await networkInfo.isConnected) {
        final token = await authLocalDataSource.getAccessToken();
        if (token != null) {
          final remoteCategory = await remoteDataSource.createCategory(token, name);
          await localDataSource.saveCategory(remoteCategory);
          return Right(remoteCategory.toEntity());
        }
      }
      
      // Offline fallback
      final localModel = VocabularyCategoryModel(
        backendId: DateTime.now().millisecondsSinceEpoch * -1, // Temporary negative ID
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      await localDataSource.saveCategory(localModel);
      return Right(localModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, VocabularyCategoryEntity>> updateCategory(int id, String name) async {
    try {
      if (await networkInfo.isConnected) {
        final token = await authLocalDataSource.getAccessToken();
        if (token != null && id > 0) { // Only update remote if it's a real backend ID
          final remoteCategory = await remoteDataSource.updateCategory(token, id, name);
          await localDataSource.saveCategory(remoteCategory);
          return Right(remoteCategory.toEntity());
        }
      }
      
      // Update local only
      final existing = await localDataSource.getCategoryById(id);
      if (existing != null) {
        existing.name = name;
        existing.updatedAt = DateTime.now();
        existing.isSynced = false;
        await localDataSource.saveCategory(existing);
        return Right(existing.toEntity());
      } else {
        return Left(const ServerFailure('Category not found locally'));
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(int id) async {
    try {
      if (await networkInfo.isConnected) {
        final token = await authLocalDataSource.getAccessToken();
        if (token != null && id > 0) {
          await remoteDataSource.deleteCategory(token, id);
        }
      }
      await localDataSource.deleteCategory(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
