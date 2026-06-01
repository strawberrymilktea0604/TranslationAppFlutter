import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frontend/core/error/api_error_handler.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/main.dart';
import 'package:http/http.dart' as http;

/// Dashboard statistics and metrics.
class DashboardStats {
  const DashboardStats({
    required this.totalUsers,
    required this.totalTranslations,
    required this.storageUsed,
    required this.uptime,
    required this.recentActivity,
  });

  final int totalUsers;
  final int totalTranslations;
  final String storageUsed;
  final double uptime;
  final List<ActivityLog> recentActivity;
}

/// Activity log entry for the admin dashboard feed.
class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.type,
    required this.message,
    required this.username,
    required this.timestamp,
  });

  final String id;
  final String type;
  final String message;
  final String username;
  final DateTime timestamp;

  factory ActivityLog.fromJson(Map<String, dynamic> json, int index) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    return ActivityLog(
      id:
          metadata['translation_id']?.toString() ??
          metadata['quiz_id']?.toString() ??
          json['actor_id']?.toString() ??
          index.toString(),
      type: json['type']?.toString() ?? 'unknown',
      message: json['description']?.toString().isNotEmpty == true
          ? json['description'].toString()
          : json['title']?.toString() ?? '',
      username: json['actor_email']?.toString() ?? 'System',
      timestamp: _parseDate(json['created_at']) ?? DateTime.now(),
    );
  }
}

/// Translation counters for the admin service-management page.
class AdminServiceSummary {
  const AdminServiceSummary({
    required this.totalTranslations,
    required this.todayTranslations,
    required this.weekTranslations,
    required this.monthTranslations,
    required this.byType,
  });

  final int totalTranslations;
  final int todayTranslations;
  final int weekTranslations;
  final int monthTranslations;
  final List<ServiceTypeCount> byType;

  factory AdminServiceSummary.fromJson(Map<String, dynamic> json) {
    return AdminServiceSummary(
      totalTranslations: json['total_translations'] as int? ?? 0,
      todayTranslations: json['today_translations'] as int? ?? 0,
      weekTranslations: json['week_translations'] as int? ?? 0,
      monthTranslations: json['month_translations'] as int? ?? 0,
      byType: _listOf(json['by_type'], ServiceTypeCount.fromJson),
    );
  }
}

/// Count and percentage for a translation service type.
class ServiceTypeCount {
  const ServiceTypeCount({
    required this.type,
    required this.count,
    required this.percentage,
  });

  final String type;
  final int count;
  final double percentage;

  factory ServiceTypeCount.fromJson(Map<String, dynamic> json) {
    return ServiceTypeCount(
      type: json['type']?.toString() ?? 'unknown',
      count: json['count'] as int? ?? 0,
      percentage: _asDouble(json['percentage']),
    );
  }
}

/// Translation row shown in the admin service-management table.
class AdminTranslationRecord {
  const AdminTranslationRecord({
    required this.id,
    required this.userId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sourceText,
    required this.translatedText,
    required this.isDeleted,
    required this.createdAt,
    this.userEmail,
    this.userName,
    this.translationType,
    this.updatedAt,
  });

  final int id;
  final int userId;
  final String? userEmail;
  final String? userName;
  final String sourceLanguage;
  final String targetLanguage;
  final String sourceText;
  final String translatedText;
  final String? translationType;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  String get displayUser => userName?.isNotEmpty == true
      ? userName!
      : userEmail?.isNotEmpty == true
      ? userEmail!
      : 'User $userId';

  factory AdminTranslationRecord.fromJson(Map<String, dynamic> json) {
    return AdminTranslationRecord(
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      userEmail: json['user_email'] as String?,
      userName: json['user_name'] as String?,
      sourceLanguage: json['source_language']?.toString() ?? '',
      targetLanguage: json['target_language']?.toString() ?? '',
      sourceText: json['source_text']?.toString() ?? '',
      translatedText: json['translated_text']?.toString() ?? '',
      translationType: json['translation_type'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

/// Paginated translation response.
class AdminTranslationListResponse {
  const AdminTranslationListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<AdminTranslationRecord> items;
  final int total;
  final int page;
  final int pageSize;

  factory AdminTranslationListResponse.fromJson(Map<String, dynamic> json) {
    return AdminTranslationListResponse(
      items: _listOf(json['items'], AdminTranslationRecord.fromJson),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }
}

/// Current metric and its comparison against the previous period.
class AdminMetricCard {
  const AdminMetricCard({
    required this.value,
    required this.previousValue,
    required this.changePercent,
  });

  final double value;
  final double previousValue;
  final double changePercent;

  factory AdminMetricCard.fromJson(Map<String, dynamic> json) {
    return AdminMetricCard(
      value: _asDouble(json['value']),
      previousValue: _asDouble(json['previous_value']),
      changePercent: _asDouble(json['change_percent']),
    );
  }
}

/// Analytics overview cards for a selected period.
class AdminAnalyticsOverview {
  const AdminAnalyticsOverview({
    required this.days,
    required this.averageTranslationsPerDay,
    required this.activeUsers,
    required this.averageResponseTimeMs,
    required this.translationAccuracyPercent,
  });

  final int days;
  final AdminMetricCard averageTranslationsPerDay;
  final AdminMetricCard activeUsers;
  final AdminMetricCard averageResponseTimeMs;
  final AdminMetricCard translationAccuracyPercent;

  factory AdminAnalyticsOverview.fromJson(Map<String, dynamic> json) {
    return AdminAnalyticsOverview(
      days: json['days'] as int? ?? 7,
      averageTranslationsPerDay: AdminMetricCard.fromJson(
        json['average_translations_per_day'] as Map<String, dynamic>? ?? {},
      ),
      activeUsers: AdminMetricCard.fromJson(
        json['active_users'] as Map<String, dynamic>? ?? {},
      ),
      averageResponseTimeMs: AdminMetricCard.fromJson(
        json['average_response_time_ms'] as Map<String, dynamic>? ?? {},
      ),
      translationAccuracyPercent: AdminMetricCard.fromJson(
        json['translation_accuracy_percent'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Source and target language usage for the analytics page.
class AdminLanguageUsage {
  const AdminLanguageUsage({
    required this.days,
    required this.sourceLanguages,
    required this.targetLanguages,
  });

  final int days;
  final List<LanguageUsageItem> sourceLanguages;
  final List<LanguageUsageItem> targetLanguages;

  factory AdminLanguageUsage.fromJson(Map<String, dynamic> json) {
    return AdminLanguageUsage(
      days: json['days'] as int? ?? 7,
      sourceLanguages: _listOf(
        json['source_languages'],
        LanguageUsageItem.fromJson,
      ),
      targetLanguages: _listOf(
        json['target_languages'],
        LanguageUsageItem.fromJson,
      ),
    );
  }
}

/// Language usage row.
class LanguageUsageItem {
  const LanguageUsageItem({
    required this.language,
    required this.count,
    required this.percentage,
  });

  final String language;
  final int count;
  final double percentage;

  factory LanguageUsageItem.fromJson(Map<String, dynamic> json) {
    return LanguageUsageItem(
      language: json['language']?.toString() ?? 'unknown',
      count: json['count'] as int? ?? 0,
      percentage: _asDouble(json['percentage']),
    );
  }
}

/// API metric row grouped by endpoint/model.
class AdminServiceMetric {
  const AdminServiceMetric({
    required this.endpoint,
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.averageResponseTimeMs,
    required this.totalTokensUsed,
    this.aiModel,
  });

  final String endpoint;
  final String? aiModel;
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final double averageResponseTimeMs;
  final int totalTokensUsed;

  factory AdminServiceMetric.fromJson(Map<String, dynamic> json) {
    return AdminServiceMetric(
      endpoint: json['endpoint']?.toString() ?? '',
      aiModel: json['ai_model'] as String?,
      totalRequests: json['total_requests'] as int? ?? 0,
      successfulRequests: json['successful_requests'] as int? ?? 0,
      failedRequests: json['failed_requests'] as int? ?? 0,
      averageResponseTimeMs: _asDouble(json['average_response_time_ms']),
      totalTokensUsed: json['total_tokens_used'] as int? ?? 0,
    );
  }
}

/// Service for dashboard, service-management, and analytics admin endpoints.
class AdminDashboardService extends ChangeNotifier {
  AdminDashboardService({http.Client? client, String? baseUrl})
    : client = client ?? http.Client(),
      baseUrl = baseUrl ?? config.apiUrl;

  final http.Client client;
  final String baseUrl;

  DashboardStats? _stats;
  AdminServiceSummary? _serviceSummary;
  List<AdminTranslationRecord> _translations = [];
  int _translationTotal = 0;
  AdminAnalyticsOverview? _analyticsOverview;
  List<ServiceTypeCount> _translationTypeBreakdown = [];
  AdminLanguageUsage? _languageUsage;
  List<AdminServiceMetric> _serviceMetrics = [];
  bool _isLoading = false;
  String? _error;

  DashboardStats? get stats => _stats;
  AdminServiceSummary? get serviceSummary => _serviceSummary;
  List<AdminTranslationRecord> get translations => _translations;
  int get translationTotal => _translationTotal;
  AdminAnalyticsOverview? get analyticsOverview => _analyticsOverview;
  List<ServiceTypeCount> get translationTypeBreakdown =>
      _translationTypeBreakdown;
  AdminLanguageUsage? get languageUsage => _languageUsage;
  List<AdminServiceMetric> get serviceMetrics => _serviceMetrics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetches the dashboard overview and recent activities.
  Future<void> fetchStats({String? accessToken}) async {
    await _load(() async {
      final token = accessToken ?? await _getToken();
      final usersResponse = await _get('/admin/users', token, {
        'page': '1',
        'page_size': '1',
      });
      final usersData = jsonDecode(usersResponse) as Map<String, dynamic>;
      final summary = await _fetchServiceSummary(token);
      final activities = await _fetchRecentActivities(token);
      final estimatedStorageGb = (summary.totalTranslations * 0.015)
          .toStringAsFixed(1);

      _serviceSummary = summary;
      _stats = DashboardStats(
        totalUsers: usersData['total'] as int? ?? 0,
        totalTranslations: summary.totalTranslations,
        storageUsed: '$estimatedStorageGb GB',
        uptime: 99.8,
        recentActivity: activities,
      );
    });
  }

  /// Fetches translation service counters.
  Future<void> fetchServiceSummary({String? accessToken}) async {
    await _load(() async {
      _serviceSummary = await _fetchServiceSummary(
        accessToken ?? await _getToken(),
      );
    });
  }

  /// Fetches paginated translations for the service-management table.
  Future<void> fetchTranslations({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? translationType,
    String? accessToken,
  }) async {
    await _load(() async {
      final token = accessToken ?? await _getToken();
      final response = await _get('/admin/services/translations', token, {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (translationType != null && translationType != 'all')
          'translation_type': translationType,
      });
      final data = AdminTranslationListResponse.fromJson(
        jsonDecode(response) as Map<String, dynamic>,
      );
      _translations = data.items;
      _translationTotal = data.total;
    });
  }

  /// Fetches all analytics data needed by the analytics page.
  Future<void> fetchAnalytics({required int days, String? accessToken}) async {
    await _load(() async {
      final token = accessToken ?? await _getToken();
      final overview = await _get('/admin/analytics/overview', token, {
        'days': days.toString(),
      });
      final typeBreakdown = await _get(
        '/admin/analytics/translation-types',
        token,
        {'days': days.toString()},
      );
      final languages = await _get('/admin/analytics/languages', token, {
        'days': days.toString(),
      });
      final metrics = await _get('/admin/analytics/services', token, {
        'days': days.toString(),
      });

      _analyticsOverview = AdminAnalyticsOverview.fromJson(
        jsonDecode(overview) as Map<String, dynamic>,
      );
      _translationTypeBreakdown = _listOf(
        (jsonDecode(typeBreakdown) as Map<String, dynamic>)['items'],
        ServiceTypeCount.fromJson,
      );
      _languageUsage = AdminLanguageUsage.fromJson(
        jsonDecode(languages) as Map<String, dynamic>,
      );
      _serviceMetrics = _listOf(
        (jsonDecode(metrics) as Map<String, dynamic>)['items'],
        AdminServiceMetric.fromJson,
      );
    });
  }

  /// Clears cached admin dashboard data.
  void clear() {
    _stats = null;
    _serviceSummary = null;
    _translations = [];
    _translationTotal = 0;
    _analyticsOverview = null;
    _translationTypeBreakdown = [];
    _languageUsage = null;
    _serviceMetrics = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<AdminServiceSummary> _fetchServiceSummary(String token) async {
    final response = await _get('/admin/services/summary', token);
    return AdminServiceSummary.fromJson(
      jsonDecode(response) as Map<String, dynamic>,
    );
  }

  Future<List<ActivityLog>> _fetchRecentActivities(String token) async {
    final response = await _get('/admin/activities/recent', token, {
      'limit': '8',
    });
    final data = jsonDecode(response) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return [
      for (var index = 0; index < items.length; index++)
        ActivityLog.fromJson(items[index] as Map<String, dynamic>, index),
    ];
  }

  Future<void> _load(Future<void> Function() action) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      await action();
    } catch (error) {
      _error = ApiErrorHandler.formatErrorMessage(error);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _getToken() async {
    final token = await sl<AuthLocalDataSource>().getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token not found. Please login again.');
    }
    return token;
  }

  Future<String> _get(
    String path,
    String token, [
    Map<String, String>? queryParameters,
  ]) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParameters);
    final response = await client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    ApiErrorHandler.handleHttpResponse(response);
    return response.body;
  }
}

List<T> _listOf<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
  final list = value as List<dynamic>? ?? [];
  return [
    for (final item in list)
      if (item is Map<String, dynamic>) fromJson(item),
  ];
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString())?.toLocal();
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}
