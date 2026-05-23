import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/app_config.dart';

/// User model for admin list display
class AdminUser {
  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String role;
  final String status;
  final DateTime createdAt;

  AdminUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  /// Get display name
  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    if (firstName != null) return firstName!;
    if (lastName != null) return lastName!;
    return email.split('@').first;
  }

  /// Check if user is banned
  bool get isBanned => status == 'locked';

  /// Create from JSON
  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as int,
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'user',
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Response model for user list
class AdminUserListResponse {
  final List<AdminUser> items;
  final int total;
  final int page;
  final int pageSize;

  AdminUserListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory AdminUserListResponse.fromJson(Map<String, dynamic> json) {
    return AdminUserListResponse(
      items: (json['items'] as List<dynamic>)
          .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }
}

/// Service for managing users (admin endpoints)
class AdminUsersService with ChangeNotifier {
  final String baseUrl;
  final http.Client client;

  List<AdminUser> _users = [];
  int _totalCount = 0;
  int _currentPage = 1;
  bool _isLoading = false;
  String? _error;

  AdminUsersService({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  // ==================== GETTERS ====================
  List<AdminUser> get users => _users;
  int get totalCount => _totalCount;
  int get currentPage => _currentPage;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ==================== PUBLIC METHODS ====================

  /// Get access token from app config or storage
  Future<String> _getToken() async {
    // TODO: Implement actual token retrieval from secure storage
    // This is a placeholder - in real app, get from SecureStorage
    throw Exception('Access token not available');
  }

  /// Fetch users list with pagination and search
  Future<void> fetchUsers({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? accessToken,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      _currentPage = page;
      notifyListeners();

      // Use provided token or try to get from storage
      final token = accessToken ?? (await _getToken());

      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse('$baseUrl/users/admin/users')
          .replace(queryParameters: queryParams);

      final response = await client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch users: ${response.body}');
      }

      final data = AdminUserListResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      _users = data.items;
      _totalCount = data.total;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ban a user
  Future<void> banUser(int userId, String accessToken) async {
    try {
      final response = await client.patch(
        Uri.parse('$baseUrl/users/admin/users/$userId/ban'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to ban user: ${response.body}');
      }

      // Update local user
      final userIndex = _users.indexWhere((u) => u.id == userId);
      if (userIndex >= 0) {
        final updatedUser = AdminUser.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        _users[userIndex] = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  /// Unban a user
  Future<void> unbanUser(int userId, String accessToken) async {
    try {
      final response = await client.patch(
        Uri.parse('$baseUrl/users/admin/users/$userId/unban'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to unban user: ${response.body}');
      }

      // Update local user
      final userIndex = _users.indexWhere((u) => u.id == userId);
      if (userIndex >= 0) {
        final updatedUser = AdminUser.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        _users[userIndex] = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  /// Clear data
  void clear() {
    _users.clear();
    _totalCount = 0;
    _currentPage = 1;
    _error = null;
    notifyListeners();
  }
}
