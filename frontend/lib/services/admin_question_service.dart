import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/core/error/api_error_handler.dart';

/// Model for a question in admin context
class AdminQuestion {
  final int id;
  final int bankId;
  final String content;
  final Map<String, dynamic> choices;
  final String correctAnswer;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminQuestion({
    required this.id,
    required this.bankId,
    required this.content,
    required this.choices,
    required this.correctAnswer,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether this question is active (not soft-deleted)
  bool get isActive => !isDeleted;

  /// Get list of choice keys
  List<String> get choiceKeys => choices.keys.toList();

  /// Get choice text by key
  String? getChoice(String key) => choices[key] as String?;

  factory AdminQuestion.fromJson(Map<String, dynamic> json) {
    return AdminQuestion(
      id: json['id'] as int,
      bankId: json['bank_id'] as int,
      content: json['content'] as String,
      choices: (json['choices'] as Map<String, dynamic>?) ?? {},
      correctAnswer: json['correct_answer'] as String,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  AdminQuestion copyWith({
    String? content,
    Map<String, dynamic>? choices,
    String? correctAnswer,
    bool? isDeleted,
  }) {
    return AdminQuestion(
      id: id,
      bankId: bankId,
      content: content ?? this.content,
      choices: choices ?? this.choices,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Paginated list response for admin questions
class AdminQuestionListResponse {
  final List<AdminQuestion> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  AdminQuestionListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory AdminQuestionListResponse.fromJson(Map<String, dynamic> json) {
    return AdminQuestionListResponse(
      items: (json['items'] as List<dynamic>)
          .map((item) => AdminQuestion.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_pages'] as int? ?? 0,
      hasNext: json['has_next'] as bool? ?? false,
      hasPrev: json['has_prev'] as bool? ?? false,
    );
  }
}

/// Service for managing questions via admin API endpoints
class AdminQuestionService with ChangeNotifier {
  final String baseUrl;
  final http.Client client;

  List<AdminQuestion> _questions = [];
  int _totalCount = 0;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = false;
  String? _error;

  AdminQuestionService({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  // ==================== GETTERS ====================
  List<AdminQuestion> get questions => _questions;
  int get totalCount => _totalCount;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasNext => _currentPage < _totalPages;
  bool get hasPrev => _currentPage > 1;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get activeCount => _questions.where((q) => q.isActive).length;
  int get inactiveCount => _questions.where((q) => !q.isActive).length;

  // ==================== HELPERS ====================

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  // ==================== PUBLIC METHODS ====================

  /// Fetch paginated list of questions in a bank
  Future<void> fetchQuestions({
    required int bankId,
    int page = 1,
    int pageSize = 20,
    bool includeDeleted = false,
    required String accessToken,
  }) async {
    _setLoading(true);
    _error = null;
    _currentPage = page;
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'include_deleted': includeDeleted.toString(),
      };

      final uri = Uri.parse('$baseUrl/admin/question-banks/$bankId/questions')
          .replace(queryParameters: queryParams);

      final response = await client.get(
        uri,
        headers: _authHeaders(accessToken),
      );

      _handleHttpErrors(response);

      final data = AdminQuestionListResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      _questions = data.items;
      _totalCount = data.total;
      _totalPages = data.totalPages;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Create a new question in a bank
  Future<AdminQuestion> createQuestion({
    required int bankId,
    required String content,
    required Map<String, dynamic> choices,
    required String correctAnswer,
    required String accessToken,
  }) async {
    _setError(null);
    try {
      final body = jsonEncode({
        'content': content,
        'choices': choices,
        'correct_answer': correctAnswer,
      });

      final response = await client.post(
        Uri.parse('$baseUrl/admin/question-banks/$bankId/questions'),
        headers: _authHeaders(accessToken),
        body: body,
      );

      _handleHttpErrors(response);

      final question = AdminQuestion.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      _questions.insert(0, question);
      _totalCount++;
      notifyListeners();
      return question;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  /// Update an existing question
  Future<AdminQuestion> updateQuestion({
    required int questionId,
    String? content,
    Map<String, dynamic>? choices,
    String? correctAnswer,
    required String accessToken,
  }) async {
    _setError(null);
    try {
      final body = jsonEncode({
        'content': ?content,
        'choices': ?choices,
        'correct_answer': ?correctAnswer,
      });

      final response = await client.put(
        Uri.parse('$baseUrl/admin/questions/$questionId'),
        headers: _authHeaders(accessToken),
        body: body,
      );

      _handleHttpErrors(response);

      final updated = AdminQuestion.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      final idx = _questions.indexWhere((q) => q.id == questionId);
      if (idx >= 0) {
        _questions[idx] = updated;
        notifyListeners();
      }
      return updated;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  /// Toggle a question active/inactive
  Future<void> toggleQuestion({
    required int questionId,
    required String accessToken,
  }) async {
    _setError(null);
    try {
      final response = await client.patch(
        Uri.parse('$baseUrl/admin/questions/$questionId/toggle'),
        headers: _authHeaders(accessToken),
      );

      _handleHttpErrors(response);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final isDeleted = json['is_deleted'] as bool;

      final idx = _questions.indexWhere((q) => q.id == questionId);
      if (idx >= 0) {
        _questions[idx] = _questions[idx].copyWith(isDeleted: isDeleted);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  /// Soft-delete a question
  Future<void> deleteQuestion({
    required int questionId,
    required String accessToken,
  }) async {
    _setError(null);
    try {
      final response = await client.delete(
        Uri.parse('$baseUrl/admin/questions/$questionId'),
        headers: _authHeaders(accessToken),
      );

      // 204 No Content is success
      if (response.statusCode != 204) {
        _handleHttpErrors(response);
      }

      _questions.removeWhere((q) => q.id == questionId);
      _totalCount = (_totalCount - 1).clamp(0, _totalCount);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  /// Clear data and reset state
  void clear() {
    _questions.clear();
    _totalCount = 0;
    _currentPage = 1;
    _totalPages = 0;
    _error = null;
    notifyListeners();
  }

  // ==================== PRIVATE ====================

  void _handleHttpErrors(http.Response response) {
    ApiErrorHandler.handleHttpResponse(response);
  }
}
