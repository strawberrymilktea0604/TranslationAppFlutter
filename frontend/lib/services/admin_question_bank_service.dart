import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/core/config/api_config.dart';
import 'package:frontend/core/services/local_data_source.dart';
import 'package:frontend/core/services/service_locator.dart';
import 'package:frontend/core/error/api_error_handler.dart';

/// Model for a question bank in admin context
class AdminQuestionBank {
  final int id;
  final String title;
  final String? description;
  final int? durationMinutes;
  final bool isDeleted;
  final int questionCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminQuestionBank({
    required this.id,
    required this.title,
    this.description,
    this.durationMinutes,
    required this.isDeleted,
    required this.questionCount,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether this bank is active (not soft-deleted)
  bool get isActive => !isDeleted;

  /// Friendly duration string
  String get durationLabel {
    if (durationMinutes == null || durationMinutes == 0) return 'Không giới hạn';
    if (durationMinutes! < 60) return '$durationMinutes phút';
    final h = durationMinutes! ~/ 60;
    final m = durationMinutes! % 60;
    return m == 0 ? '$h giờ' : '$h giờ $m phút';
  }

  factory AdminQuestionBank.fromJson(Map<String, dynamic> json) {
    return AdminQuestionBank(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      questionCount: json['question_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  AdminQuestionBank copyWith({
    String? title,
    String? description,
    int? durationMinutes,
    bool? isDeleted,
    int? questionCount,
  }) {
    return AdminQuestionBank(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isDeleted: isDeleted ?? this.isDeleted,
      questionCount: questionCount ?? this.questionCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Paginated list response for admin question banks
class AdminQuestionBankListResponse {
  final List<AdminQuestionBank> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  AdminQuestionBankListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory AdminQuestionBankListResponse.fromJson(Map<String, dynamic> json) {
    return AdminQuestionBankListResponse(
      items: (json['items'] as List<dynamic>)
          .map((item) => AdminQuestionBank.fromJson(item as Map<String, dynamic>))
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

/// Service for managing question banks via admin API endpoints
class AdminQuestionBankService with ChangeNotifier {
  final String baseUrl;
  final http.Client client;

  List<AdminQuestionBank> _banks = [];
  int _totalCount = 0;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = false;
  String? _error;

  AdminQuestionBankService({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  // ==================== GETTERS ====================
  List<AdminQuestionBank> get banks => _banks;
  int get totalCount => _totalCount;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get activeCount => _banks.where((b) => b.isActive).length;
  int get inactiveCount => _banks.where((b) => !b.isActive).length;

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

  /// Fetch paginated list of question banks
  Future<void> fetchBanks({
    int page = 1,
    int pageSize = 20,
    String? search,
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
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse('$baseUrl/admin/question-banks')
          .replace(queryParameters: queryParams);

      final response = await client.get(
        uri,
        headers: _authHeaders(accessToken),
      );

      _handleHttpErrors(response);

      final data = AdminQuestionBankListResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      _banks = data.items;
      _totalCount = data.total;
      _totalPages = data.totalPages;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Create a new question bank
  Future<AdminQuestionBank> createBank({
    required String title,
    String? description,
    int? durationMinutes,
    required String accessToken,
  }) async {
    _setError(null);
    try {
      final body = jsonEncode({
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
      });

      final response = await client.post(
        Uri.parse('$baseUrl/admin/question-banks'),
        headers: _authHeaders(accessToken),
        body: body,
      );

      _handleHttpErrors(response);

      final bank = AdminQuestionBank.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      _banks.insert(0, bank);
      _totalCount++;
      notifyListeners();
      return bank;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  /// Update an existing question bank
  Future<AdminQuestionBank> updateBank({
    required int bankId,
    String? title,
    String? description,
    int? durationMinutes,
    required String accessToken,
  }) async {
    _setError(null);
    try {
      final body = jsonEncode({
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
      });

      final response = await client.put(
        Uri.parse('$baseUrl/admin/question-banks/$bankId'),
        headers: _authHeaders(accessToken),
        body: body,
      );

      _handleHttpErrors(response);

      final updated = AdminQuestionBank.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      final idx = _banks.indexWhere((b) => b.id == bankId);
      if (idx >= 0) {
        _banks[idx] = updated;
        notifyListeners();
      }
      return updated;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  /// Toggle a bank active/inactive
  Future<void> toggleBank({
    required int bankId,
    required String accessToken,
  }) async {
    _setError(null);
    try {
      final response = await client.patch(
        Uri.parse('$baseUrl/admin/question-banks/$bankId/toggle'),
        headers: _authHeaders(accessToken),
      );

      _handleHttpErrors(response);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final isDeleted = json['is_deleted'] as bool;

      final idx = _banks.indexWhere((b) => b.id == bankId);
      if (idx >= 0) {
        _banks[idx] = _banks[idx].copyWith(isDeleted: isDeleted);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  /// Soft-delete a bank
  Future<void> deleteBank({
    required int bankId,
    required String accessToken,
  }) async {
    _setError(null);
    try {
      final response = await client.delete(
        Uri.parse('$baseUrl/admin/question-banks/$bankId'),
        headers: _authHeaders(accessToken),
      );

      // 204 No Content is success
      if (response.statusCode != 204) {
        _handleHttpErrors(response);
      }

      _banks.removeWhere((b) => b.id == bankId);
      _totalCount = (_totalCount - 1).clamp(0, _totalCount);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  /// Clear data and reset state
  void clear() {
    _banks.clear();
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
