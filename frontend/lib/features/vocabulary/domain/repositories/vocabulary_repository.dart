import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/vocabulary/domain/entities/vocabulary_entity.dart';

/// Abstract repository for vocabulary feature.
/// UC07 — Lưu từ vựng (offline-first).
abstract class VocabularyRepository {
  Future<Either<Failure, List<VocabularyEntity>>> getVocabularyList();
  Future<Either<Failure, VocabularyEntity>> saveVocabulary({
    required String word,
    required String translation,
    required String sourceLanguage,
    required String targetLanguage,
  });
  Future<Either<Failure, void>> deleteVocabulary(String id);
}
