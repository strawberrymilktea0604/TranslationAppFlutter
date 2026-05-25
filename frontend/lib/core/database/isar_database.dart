import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/auth/data/models/user_model.dart';
import '../../features/history/data/models/history_model.dart';
import '../../features/vocabulary/data/models/vocabulary_model.dart';
import '../../features/vocabulary/data/models/vocabulary_category_model.dart';
import '../../features/vocabulary/data/models/question_bank_model.dart';
import '../../features/vocabulary/data/models/quiz_result_model.dart';

class IsarDatabase {
  /// Nullable — not initialized on Web (Isar 3.x has no web support).
  Isar? _isar;

  Isar get isar {
    assert(_isar != null,
        'IsarDatabase.isar accessed on Web or before init() was called.');
    return _isar!;
  }

  bool get isInitialized => _isar != null;

  /// Initializes Isar. Must NOT be called on Flutter Web.
  Future<void> init() async {
    if (kIsWeb) return; // Isar 3.x does not support Web

    final dir = await getApplicationDocumentsDirectory();
    
    try {
      _isar = await Isar.open([
        UserModelSchema,
        HistoryModelSchema,
        VocabularyModelSchema,
        VocabularyCategoryModelSchema,
        QuestionBankModelSchema,
        QuizResultModelSchema,
      ], directory: dir.path);
    } catch (e) {
      debugPrint('Isar open failed: $e. Attempting to delete and recreate database...');
      // Delete old database files if schema mismatch or corruption occurs
      final dbFile = File('${dir.path}/default.isar');
      final lockFile = File('${dir.path}/default.isar.lock');
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      if (await lockFile.exists()) {
        await lockFile.delete();
      }
      
      // Try opening again
      _isar = await Isar.open([
        UserModelSchema,
        HistoryModelSchema,
        VocabularyModelSchema,
        VocabularyCategoryModelSchema,
        QuestionBankModelSchema,
        QuizResultModelSchema,
      ], directory: dir.path);
    }
  }
}
