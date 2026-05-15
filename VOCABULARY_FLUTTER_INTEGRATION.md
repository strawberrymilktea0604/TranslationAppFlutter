"""
Flutter Integration Guide - Vocabulary Service Example

This file shows how to implement vocabulary management in Flutter app.
Copy and adapt this code to your project.
"""

# ============== MODELS ==============

# lib/models/vocabulary_model.dart
"""
class VocabularyDetail {
  final int id;
  final int userId;
  final int translationId;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Translation details
  final String sourceLanguage;
  final String targetLanguage;
  final String sourceText;
  final String translatedText;
  final String? translationType;
  final DateTime? translationCreatedAt;

  VocabularyDetail({
    required this.id,
    required this.userId,
    required this.translationId,
    required this.isDeleted,
    required this.createdAt,
    this.updatedAt,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sourceText,
    required this.translatedText,
    this.translationType,
    this.translationCreatedAt,
  });

  factory VocabularyDetail.fromJson(Map<String, dynamic> json) {
    return VocabularyDetail(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      translationId: json['translation_id'] as int,
      isDeleted: json['is_deleted'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at'] as String)
        : null,
      sourceLanguage: json['source_language'] as String,
      targetLanguage: json['target_language'] as String,
      sourceText: json['source_text'] as String,
      translatedText: json['translated_text'] as String,
      translationType: json['translation_type'] as String?,
      translationCreatedAt: json['translation_created_at'] != null
        ? DateTime.parse(json['translation_created_at'] as String)
        : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'translation_id': translationId,
    'is_deleted': isDeleted,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'source_language': sourceLanguage,
    'target_language': targetLanguage,
    'source_text': sourceText,
    'translated_text': translatedText,
    'translation_type': translationType,
    'translation_created_at': translationCreatedAt?.toIso8601String(),
  };
}


class VocabularyListResponse {
  final List<VocabularyDetail> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  VocabularyListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory VocabularyListResponse.fromJson(Map<String, dynamic> json) {
    return VocabularyListResponse(
      items: List<VocabularyDetail>.from(
        (json['items'] as List).map((x) => VocabularyDetail.fromJson(x as Map<String, dynamic>))
      ),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      totalPages: json['total_pages'] as int,
      hasNext: json['has_next'] as bool,
      hasPrev: json['has_prev'] as bool,
    );
  }
}
"""


# ============== SERVICE ==============

# lib/services/vocabulary_service.dart
"""
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:translation_app/models/vocabulary_model.dart';
import 'package:translation_app/services/auth_service.dart';

class VocabularyService with ChangeNotifier {
  final String baseUrl = 'http://localhost:8000/api/v1';
  final AuthService authService;
  
  List<VocabularyDetail> _vocabularies = [];
  int _totalCount = 0;
  bool _isLoading = false;
  String? _error;

  VocabularyService(this.authService);

  // Getters
  List<VocabularyDetail> get vocabularies => _vocabularies;
  int get totalCount => _totalCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<String> _getToken() async {
    final token = await authService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');
    return token;
  }

  /// Add single translation to vocabulary
  Future<void> addToVocabulary(int translationId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/vocabularies'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'translation_id': translationId}),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to add: ${response.body}');
      }

      // Refresh list after adding
      await getVocabularies(page: 1);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add multiple translations to vocabulary
  Future<void> addMultipleToVocabulary(List<int> translationIds) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/vocabularies/batch'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'translation_ids': translationIds}),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to add multiple: ${response.body}');
      }

      // Refresh list
      await getVocabularies(page: 1);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get paginated vocabulary list
  Future<void> getVocabularies({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final token = await _getToken();
      
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse('$baseUrl/vocabularies')
        .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch: ${response.body}');
      }

      final data = VocabularyListResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>
      );

      _vocabularies = data.items;
      _totalCount = data.total;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get vocabulary details
  Future<VocabularyDetail> getVocabularyDetail(int vocabularyId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/vocabularies/$vocabularyId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Not found');
      }

      return VocabularyDetail.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  /// Remove from vocabulary
  Future<void> removeFromVocabulary(int vocabularyId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/vocabularies/$vocabularyId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove');
      }

      // Remove from local list
      _vocabularies.removeWhere((v) => v.id == vocabularyId);
      _totalCount--;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove multiple from vocabulary
  Future<void> removeMultipleFromVocabulary(List<int> translationIds) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/vocabularies/batch/remove'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'translation_ids': translationIds}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove multiple');
      }

      // Refresh list
      await getVocabularies(page: 1);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restore deleted vocabulary entry
  Future<void> restoreVocabulary(int vocabularyId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/vocabularies/$vocabularyId/restore'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to restore');
      }

      // Refresh list
      await getVocabularies(page: 1);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get vocabulary statistics
  Future<Map<String, dynamic>> getVocabularyStats() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/vocabularies/stats/summary'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch stats');
      }

      final data = jsonDecode(response.body);
      return data['data'] as Map<String, dynamic>;
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }
}
"""


# ============== PROVIDER SETUP ==============

# lib/injection_container.dart (or main.dart)
"""
// Add to your provider setup:

final vocabularyServiceProvider = ChangeNotifierProvider((ref) {
  final authService = ref.watch(authServiceProvider);
  return VocabularyService(authService);
});
"""


# ============== UI EXAMPLE ==============

# lib/screens/vocabulary_screen.dart
"""
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translation_app/services/vocabulary_service.dart';

class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen> {
  int _currentPage = 1;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load vocabulary on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vocabularyServiceProvider).getVocabularies(page: 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vocabularyService = ref.watch(vocabularyServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vocabulary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              vocabularyService.getVocabularies(
                page: 1,
                search: _searchQuery.isNotEmpty ? _searchQuery : null,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search vocabularies...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                vocabularyService.getVocabularies(
                  page: 1,
                  search: value.isNotEmpty ? value : null,
                );
              },
            ),
          ),
          // Vocabulary list
          Expanded(
            child: vocabularyService.isLoading
              ? const Center(child: CircularProgressIndicator())
              : vocabularyService.vocabularies.isEmpty
                ? const Center(child: Text('No vocabularies found'))
                : ListView.builder(
                  itemCount: vocabularyService.vocabularies.length,
                  itemBuilder: (context, index) {
                    final vocab = vocabularyService.vocabularies[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(vocab.sourceText),
                        subtitle: Text(vocab.translatedText),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await vocabularyService
                              .removeFromVocabulary(vocab.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Removed from vocabulary'),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
"""

# ============== GUEST USER (LOCAL STORAGE) ==============

# lib/services/local_vocabulary_service.dart
"""
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class LocalVocabularyService {
  static const String _dbName = 'vocabulary.db';
  static const String _tableName = 'vocabularies';
  
  Database? _db;

  Future<Database> get db async {
    return _db ??= await _initDb();
  }

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

  Future<void> saveVocabularyLocally(Map<String, dynamic> translation) async {
    final database = await db;
    await database.insert(
      _tableName,
      {
        'source_text': translation['source_text'],
        'translated_text': translation['translated_text'],
        'source_language': translation['source_language'],
        'target_language': translation['target_language'],
        'translation_type': translation['translation_type'],
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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
    
    return database.query(
      _tableName,
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteLocalVocabulary(int id) async {
    final database = await db;
    await database.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllLocal() async {
    final database = await db;
    await database.delete(_tableName);
  }
}
"""

"""
