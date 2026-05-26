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

  /// Schema list used for Isar.open — defined once to avoid duplication.
  static const _schemas = [
    UserModelSchema,
    HistoryModelSchema,
    VocabularyModelSchema,
    VocabularyCategoryModelSchema,
    QuestionBankModelSchema,
    QuizResultModelSchema,
  ];

  /// Initializes Isar. Must NOT be called on Flutter Web.
  Future<void> init() async {
    if (kIsWeb) return; // Isar 3.x does not support Web

    final dir = await getApplicationDocumentsDirectory();

    try {
      _isar = await Isar.open(
        _schemas,
        directory: dir.path,
      );
    } catch (e) {
      debugPrint(
        '[IsarDatabase] Isar.open failed: $e\n'
        'Deleting corrupted database and retrying…',
      );

      // 1. Try to close any lingering Isar instance gracefully.
      try {
        final existing = Isar.getInstance();
        if (existing != null && existing.isOpen) {
          await existing.close(deleteFromDisk: true);
        }
      } catch (_) {
        // Instance may not exist or may already be broken — ignore.
      }

      // 2. Manually delete ALL Isar-related files to guarantee a clean slate.
      final filesToDelete = [
        File('${dir.path}/default.isar'),
        File('${dir.path}/default.isar.lock'),
        File('${dir.path}/default.isar.wal'),
      ];
      for (final f in filesToDelete) {
        try {
          if (await f.exists()) await f.delete();
        } catch (deleteErr) {
          debugPrint('[IsarDatabase] Could not delete ${f.path}: $deleteErr');
        }
      }

      // 3. Re-open with the **same default name** so the rest of the app
      //    (injection_container, datasources) finds the correct instance.
      _isar = await Isar.open(
        _schemas,
        directory: dir.path,
      );

      debugPrint('[IsarDatabase] Database recreated successfully.');
    }
  }
}
