import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/vocabulary_entity.dart';
import '../../domain/repositories/vocabulary_repository.dart';
import '../datasources/vocabulary_local_datasource.dart';
import '../models/vocabulary_model.dart';

/// Offline-first implementation of [VocabularyRepository].
///
/// UC07 — Lưu từ vựng:
/// - Save always goes to Isar (local) first with [isSynced] = false.
/// - Read always returns data from Isar (local).
/// - Syncing to server is handled by the Sync feature separately.
class VocabularyRepositoryImpl implements VocabularyRepository {
  final VocabularyLocalDataSource _localDataSource;

  VocabularyRepositoryImpl({
    required VocabularyLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  @override
  Future<Either<Failure, VocabularyEntity>> saveVocabulary({
    required String word,
    required String translation,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final now = DateTime.now();
      final model = VocabularyModel(
        // Generate a temporary local ID; the server will assign
        // the real UUID upon sync.
        backendId: 'local_${now.millisecondsSinceEpoch}',
        word: word,
        translation: translation,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        createdAt: now,
        updatedAt: now,
        isSynced: false,
        isDeleted: false,
      );

      final saved = await _localDataSource.saveVocabulary(model);
      return Right(saved.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<VocabularyEntity>>> getVocabularyList() async {
    try {
      final models = await _localDataSource.getVocabularyList();
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteVocabulary(String id) async {
    try {
      // The domain layer uses the string backendId.
      // We need to find the Isar record by backendId to get the
      // int-based Isar primary key, then soft-delete.
      // For simplicity, the Cubit passes the Isar int id as a string.
      final isarId = int.tryParse(id);
      if (isarId == null) {
        return const Left(
          CacheFailure('Invalid vocabulary ID format'),
        );
      }
      await _localDataSource.deleteVocabulary(isarId);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
