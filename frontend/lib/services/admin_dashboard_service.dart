import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:frontend/main.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/core/error/api_error_handler.dart';

/// Dashboard statistics and metrics
class DashboardStats {
  final int totalUsers;
  final int totalTranslations;
  final String storageUsed;
  final double uptime;
  final List<ActivityLog> recentActivity;

  DashboardStats({
    required this.totalUsers,
    required this.totalTranslations,
    required this.storageUsed,
    required this.uptime,
    required this.recentActivity,
  });
}

/// Activity log entry
class ActivityLog {
  final String id;
  final String type;
  final String message;
  final String username;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.type,
    required this.message,
    required this.username,
    required this.timestamp,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'unknown',
      message: json['message'] ?? '',
      username: json['username'] ?? 'Unknown',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
    );
  }
}

/// Service for dashboard statistics and metrics
class AdminDashboardService extends ChangeNotifier {
  final http.Client client;
  final String baseUrl;

  DashboardStats? _stats;
  bool _isLoading = false;
  String? _error;

  AdminDashboardService({
    http.Client? client,
    String? baseUrl,
  })  : client = client ?? http.Client(),
        baseUrl = baseUrl ?? config.apiUrl;

  // Getters
  DashboardStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch dashboard statistics
  Future<void> fetchStats({String? accessToken}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final token = accessToken ?? (await _getToken());

      // Fetch user count
      final usersResponse = await _fetchWithAuth(
        '$baseUrl/admin/users?page=1&page_size=1',
        token,
      );
      final usersData = jsonDecode(usersResponse) as Map<String, dynamic>;
      final totalUsers = usersData['total'] ?? 0;

      // Fetch translation statistics (if endpoint exists)
      int totalTranslations = 0;
      try {
        final translationsResponse = await _fetchWithAuth(
          '$baseUrl/api/v1/translations?page=1&page_size=1',
          token,
        );
        final translationsData =
            jsonDecode(translationsResponse) as Map<String, dynamic>;
        totalTranslations = translationsData['total'] ?? 0;
      } catch (_) {
        // Translation endpoint might not exist or might not return total
        totalTranslations = 0;
      }

      // Calculate estimated storage (simplified)
      // In real scenario, this would come from an endpoint
      final estimatedStorageGB =
          (totalTranslations * 0.015).toStringAsFixed(1); // ~15KB per translation

      // Create mock activity log for now
      final recentActivity = _generateMockActivityLog();

      _stats = DashboardStats(
        totalUsers: totalUsers,
        totalTranslations: totalTranslations,
        storageUsed: '$estimatedStorageGB GB',
        uptime: 99.8,
        recentActivity: recentActivity,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch only user count
  Future<int> fetchUserCount({String? accessToken}) async {
    try {
      final token = accessToken ?? (await _getToken());
      final response = await _fetchWithAuth(
        '$baseUrl/admin/users?page=1&page_size=1',
        token,
      );
      final data = jsonDecode(response) as Map<String, dynamic>;
      return data['total'] ?? 0;
    } catch (e) {
      _error = e.toString();
      return 0;
    }
  }

  /// Fetch only translation count
  Future<int> fetchTranslationCount({String? accessToken}) async {
    try {
      final token = accessToken ?? (await _getToken());
      final response = await _fetchWithAuth(
        '$baseUrl/api/v1/translations?page=1&page_size=1',
        token,
      );
      final data = jsonDecode(response) as Map<String, dynamic>;
      return data['total'] ?? 0;
    } catch (e) {
      _error = e.toString();
      return 0;
    }
  }

  /// Clear all data
  void clear() {
    _stats = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  // ==================== PRIVATE ====================

  Future<String> _getToken() async {
    try {
      return await sl<AuthLocalDataSource>().getAccessToken() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<String> _fetchWithAuth(String url, String token) async {
    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    _handleHttpErrors(response);
    return response.body;
  }

  void _handleHttpErrors(http.Response response) {
    ApiErrorHandler.handleHttpResponse(response);
  }

  List<ActivityLog> _generateMockActivityLog() {
    // Generate mock activity for demo purposes
    // In production, fetch from an activity log endpoint
    final now = DateTime.now();
    return [
      ActivityLog(
        id: '1',
        type: 'user_signup',
        message: 'Người dùng mới đăng ký',
        username: 'user_${now.millisecond}',
        timestamp: now,
      ),
      ActivityLog(
        id: '2',
        type: 'translation',
        message: 'Dịch hệ thống',
        username: 'system_user',
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
      ActivityLog(
        id: '3',
        type: 'quiz_created',
        message: 'Tạo bộ câu hỏi mới',
        username: 'admin_user',
        timestamp: now.subtract(const Duration(minutes: 15)),
      ),
      ActivityLog(
        id: '4',
        type: 'user_login',
        message: 'Người dùng đăng nhập',
        username: 'user_${now.millisecond - 100}',
        timestamp: now.subtract(const Duration(minutes: 30)),
      ),
      ActivityLog(
        id: '5',
        type: 'user_banned',
        message: 'Người dùng bị khóa',
        username: 'spammer_user',
        timestamp: now.subtract(const Duration(minutes: 45)),
      ),
    ];
  }
}
