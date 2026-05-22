// Vocabulary Service for Flutter app.
// Handles API calls to backend vocabulary endpoints.

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:frontend/models/vocabulary_model.dart';

class AuthService {
  /// Get access token - IMPLEMENT THIS IN YOUR ACTUAL AUTH SERVICE
  Future<String?> getAccessToken() async {
    // TODO: Implement to return actual JWT token
    // Example: return await _secureStorage.read(key: 'access_token');
    return null;
  }

  /// Check if user is authenticated
  bool get isAuthenticated {
    // TODO: Implement to check if user is logged in
    return false;
  }
}

class VocabularyService with ChangeNotifier {
  final String baseUrl = 'http://localhost:8000/api/v1';
  final AuthService authService;
  
  List<VocabularyDetail> _vocabularies = [];
  int _totalCount = 0;
  bool _isLoading = false;
  String? _error;

  VocabularyService(this.authService);

  // ==================== GETTERS ====================

  List<VocabularyDetail> get vocabularies => _vocabularies;
  int get totalCount => _totalCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ==================== PRIVATE METHODS ====================

  Future<String> _getToken() async {
    final token = await authService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');
    return token;
  }

  // ==================== PUBLIC METHODS ====================

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
