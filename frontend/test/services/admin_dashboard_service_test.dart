import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/admin_dashboard_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AdminDashboardService', () {
    test(
      'fetchStats loads users, service summary, and recent activities',
      () async {
        final service = AdminDashboardService(
          baseUrl: 'http://localhost:8000/api/v1',
          client: _mockClient(),
        );

        await service.fetchStats(accessToken: 'token');

        expect(service.error, isNull);
        expect(service.stats?.totalUsers, 3);
        expect(service.stats?.totalTranslations, 120);
        expect(service.stats?.recentActivity, hasLength(1));
        expect(service.serviceSummary?.todayTranslations, 12);
      },
    );

    test('fetchTranslations loads paginated translation records', () async {
      final service = AdminDashboardService(
        baseUrl: 'http://localhost:8000/api/v1',
        client: _mockClient(),
      );

      await service.fetchTranslations(accessToken: 'token');

      expect(service.translationTotal, 1);
      expect(service.translations.single.displayUser, 'User One');
      expect(service.translations.single.translationType, 'text');
    });

    test('fetchAnalytics loads overview and breakdown data', () async {
      final service = AdminDashboardService(
        baseUrl: 'http://localhost:8000/api/v1',
        client: _mockClient(),
      );

      await service.fetchAnalytics(days: 7, accessToken: 'token');

      expect(service.analyticsOverview?.activeUsers.value, 3.0);
      expect(service.translationTypeBreakdown.single.type, 'text');
      expect(service.languageUsage?.targetLanguages.single.language, 'vi');
      expect(service.serviceMetrics.single.totalRequests, 120);
    });
  });
}

http.Client _mockClient() {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/admin/users')) {
      return _json({'items': [], 'total': 3, 'page': 1, 'page_size': 1});
    }
    if (path.endsWith('/admin/services/summary')) {
      return _json({
        'total_translations': 120,
        'today_translations': 12,
        'week_translations': 48,
        'month_translations': 120,
        'by_type': [
          {'type': 'text', 'count': 120, 'percentage': 100.0},
        ],
      });
    }
    if (path.endsWith('/admin/activities/recent')) {
      return _json({
        'items': [
          {
            'type': 'translation',
            'title': 'Translation created',
            'description': 'Hello',
            'actor_id': 1,
            'actor_email': 'user1@test.com',
            'created_at': '2026-06-01T10:00:00.000Z',
            'metadata': {'translation_id': 1000},
          },
        ],
      });
    }
    if (path.endsWith('/admin/services/translations')) {
      return _json({
        'items': [
          {
            'id': 1000,
            'user_id': 1,
            'user_email': 'user1@test.com',
            'user_name': 'User One',
            'source_language': 'en',
            'target_language': 'vi',
            'source_text': 'Hello',
            'translated_text': 'Xin chao',
            'translation_type': 'text',
            'is_deleted': false,
            'created_at': '2026-06-01T10:00:00.000Z',
            'updated_at': '2026-06-01T10:00:00.000Z',
          },
        ],
        'total': 1,
        'page': 1,
        'page_size': 20,
      });
    }
    if (path.endsWith('/admin/analytics/overview')) {
      return _json({
        'days': 7,
        'average_translations_per_day': {
          'value': 17.14,
          'previous_value': 12.0,
          'change_percent': 42.86,
        },
        'active_users': {
          'value': 3.0,
          'previous_value': 2.0,
          'change_percent': 50.0,
        },
        'average_response_time_ms': {
          'value': 245.0,
          'previous_value': 260.0,
          'change_percent': -5.77,
        },
        'translation_accuracy_percent': {
          'value': 94.2,
          'previous_value': 93.0,
          'change_percent': 1.29,
        },
      });
    }
    if (path.endsWith('/admin/analytics/translation-types')) {
      return _json({
        'days': 7,
        'items': [
          {'type': 'text', 'count': 120, 'percentage': 100.0},
        ],
      });
    }
    if (path.endsWith('/admin/analytics/languages')) {
      return _json({
        'days': 7,
        'source_languages': [
          {'language': 'en', 'count': 120, 'percentage': 100.0},
        ],
        'target_languages': [
          {'language': 'vi', 'count': 120, 'percentage': 100.0},
        ],
      });
    }
    if (path.endsWith('/admin/analytics/services')) {
      return _json({
        'days': 7,
        'items': [
          {
            'endpoint': 'translation/text',
            'ai_model': 'test-model',
            'total_requests': 120,
            'successful_requests': 118,
            'failed_requests': 2,
            'average_response_time_ms': 245.0,
            'total_tokens_used': 0,
          },
        ],
      });
    }
    return http.Response('Not Found', 404);
  });
}

http.Response _json(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
}
