import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/features/translation/domain/entities/translation_entity.dart';

/// Abstract repository interface for translation feature.
/// Defined in Domain layer — implemented in Data layer.
abstract class TranslationRepository {
  /// Translates text from source to target language.
  /// Returns [TranslationEntity] on success, [Failure] on error.
  Future<Either<Failure, TranslationEntity>> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });

  /// Switches source and target languages.
  Future<Either<Failure, void>> switchLanguages({
    required String currentSource,
    required String currentTarget,
  });
}
