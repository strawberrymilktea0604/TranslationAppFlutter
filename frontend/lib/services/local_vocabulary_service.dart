// Local Vocabulary Service for Flutter app.
// Handles local SQLite storage for guest users and offline support.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class LocalVocabularyService {
  static const String _dbName = 'vocabulary.db';
  static const String _tableName = 'vocabularies';

  Database? _db;

  /// Get or initialize database
  Future<Database> get db async {
    return _db ??= await _initDb();
  }

  /// Initialize database
  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      path.join(dbPath, _dbName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_text TEXT NOT NULL,
            translated_text TEXT NOT NULL,
            source_language TEXT NOT NULL,
            target_language TEXT NOT NULL,
            translation_type TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Save vocabulary entry locally
  Future<void> saveVocabularyLocally(Map<String, dynamic> translation) async {
    final database = await db;
    await database.insert(_tableName, {
      'source_text': translation['source_text'],
      'translated_text': translation['translated_text'],
      'source_language': translation['source_language'],
      'target_language': translation['target_language'],
      'translation_type': translation['translation_type'],
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get all local vocabularies with optional search
  Future<List<Map<String, dynamic>>> getLocalVocabularies({
    String? search,
  }) async {
    final database = await db;

    if (search != null && search.isNotEmpty) {
      return database.query(
        _tableName,
        where: '''
          source_text LIKE ? OR translated_text LIKE ?
        ''',
        whereArgs: ['%$search%', '%$search%'],
        orderBy: 'created_at DESC',
      );
    }

    return database.query(_tableName, orderBy: 'created_at DESC');
  }

  /// Delete specific vocabulary entry
  Future<void> deleteLocalVocabulary(int id) async {
    final database = await db;
    await database.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Clear all local vocabularies
  Future<void> clearAllLocal() async {
    final database = await db;
    await database.delete(_tableName);
  }

  /// Get count of local vocabularies
  Future<int> getLocalVocabularyCount() async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
