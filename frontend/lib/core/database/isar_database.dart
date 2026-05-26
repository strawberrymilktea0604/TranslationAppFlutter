import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
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

  /// Deletes all Isar database files for the given [name] in [dirPath].
  ///
  /// Isar 3.x creates up to three files: `<name>.isar`, `<name>.isar.lock`,
  /// and `<name>.isar.wal`.
  static Future<void> _nukeDbFiles(String dirPath, String name) async {
    final suffixes = ['', '.lock', '.wal'];
    for (final s in suffixes) {
      final f = File('$dirPath/$name.isar$s');
      try {
        if (await f.exists()) {
          await f.delete();
          debugPrint('[IsarDatabase] Deleted ${f.path}');
        }
      } catch (e) {
        debugPrint('[IsarDatabase] Could not delete ${f.path}: $e');
      }
    }
  }

  /// Initializes Isar. Must NOT be called on Flutter Web.
  ///
  /// Strategy:
  ///   1. Try to open with the default name.
  ///   2. If that fails (e.g. schema mismatch from an old DB), the Isar
  ///      internal registry is tainted for name "default" in this process.
  ///      We cannot re-open the same name again.
  ///   3. So we nuke all DB files for **both** names (default + fallback),
  ///      then open with a different name (`app_db`) that has no tainted
  ///      registry entry.
  Future<void> init() async {
    if (kIsWeb) return; // Isar 3.x does not support Web

    final dir = await getApplicationDocumentsDirectory();

    try {
      _isar = await Isar.open(
        _schemas,
        directory: dir.path,
      );
      return; // Success — nothing else to do.
    } catch (e) {
      debugPrint(
        '[IsarDatabase] Primary Isar.open failed: $e\n'
        'Will nuke old DB files and retry with a fallback name…',
      );
    }

    // ── Cleanup: close any half-opened instance & delete files ──────────
    try {
      final existing = Isar.getInstance();
      if (existing != null && existing.isOpen) {
        await existing.close(deleteFromDisk: true);
      }
    } catch (_) {}

    // Delete files for both the default and fallback names.
    await _nukeDbFiles(dir.path, 'default');
    await _nukeDbFiles(dir.path, 'app_db');

    // ── Retry with a fresh name that Isar hasn't registered yet ─────────
    try {
      _isar = await Isar.open(
        _schemas,
        directory: dir.path,
        name: 'app_db',
      );
      debugPrint('[IsarDatabase] Fallback database "app_db" opened successfully.');
    } catch (retryErr) {
      debugPrint(
        '[IsarDatabase] CRITICAL — Fallback Isar.open also failed: $retryErr\n'
        'The app will run without a local database. '
        'All offline features will be unavailable.',
      );
      // _isar stays null — callers must check isInitialized.
    }
  }
}
