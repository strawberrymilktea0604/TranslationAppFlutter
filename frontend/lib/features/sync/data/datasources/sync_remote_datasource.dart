import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../../../../core/error/exceptions.dart';
import '../models/sync_model.dart';
import '../models/sync_push_model.dart';
import '../models/sync_pull_model.dart';

/// Remote data source for the sync feature.
///
/// Supports both the legacy vocabulary-only endpoint and the
/// modern multi-resource push/pull protocol.
abstract class SyncRemoteDataSource {
  /// Sends a batch of unsynced vocabulary items to the server.
  /// (Legacy endpoint: `POST /api/v1/sync/vocabulary`)
  ///
  /// Throws [ServerException] on non-2xx responses.
  /// Throws [AuthException] on 401 (token expired).
  Future<SyncResponseModel> syncVocabulary({
    required SyncVocabularyRequestModel request,
    required String accessToken,
  });

  /// Pushes a batch of mixed-resource items to the server.
  /// (Modern endpoint: `POST /api/v1/sync/push`)
  ///
  /// Throws [ServerException] on non-2xx responses.
  /// Throws [AuthException] on 401 (token expired).
  Future<SyncPushResponseModel> pushChanges({
    required SyncPushRequestModel request,
    required String accessToken,
  });

  /// Pulls a page of server changes using cursor-based pagination.
  /// (Modern endpoint: `GET /api/v1/sync/pull`)
  ///
  /// [cursor] is null for the first pull (fetches all history).
  ///
  /// Throws [ServerException] on non-2xx responses.
  /// Throws [AuthException] on 401 (token expired).
  Future<SyncPullResponseModel> pullChanges({
    String? cursor,
    int limit,
    required String accessToken,
  });
}

/// HTTP implementation of [SyncRemoteDataSource].
class SyncRemoteDataSourceImpl implements SyncRemoteDataSource {
  final http.Client _client;
  final String _baseUrl;

  SyncRemoteDataSourceImpl({
    required http.Client client,
    required String baseUrl,
  })  : _client = client,
        _baseUrl = baseUrl;

  @override
  Future<SyncResponseModel> syncVocabulary({
    required SyncVocabularyRequestModel request,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/sync/vocabulary');

    developer.log(
      'POST $uri — ${request.items.length} items',
      name: 'SyncRemoteDataSource',
    );

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 401) {
        throw const AuthException(
          message: 'Access token expired during sync',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ServerException(
          message: 'Sync API returned ${response.statusCode}: '
              '${response.body}',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SyncResponseModel.fromJson(json);
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Network error during sync: $e',
      );
    }
  }

  @override
  Future<SyncPushResponseModel> pushChanges({
    required SyncPushRequestModel request,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/sync/push');

    developer.log(
      'POST $uri — ${request.items.length} items',
      name: 'SyncRemoteDataSource',
    );

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 401) {
        throw const AuthException(
          message: 'Access token expired during push sync',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ServerException(
          message: 'Push sync API returned ${response.statusCode}: '
              '${response.body}',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SyncPushResponseModel.fromJson(json);
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Network error during push sync: $e',
      );
    }
  }

  @override
  Future<SyncPullResponseModel> pullChanges({
    String? cursor,
    int limit = 100,
    required String accessToken,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    if (cursor != null) {
      queryParams['cursor'] = cursor;
    }

    final uri = Uri.parse('$_baseUrl/sync/pull')
        .replace(queryParameters: queryParams);

    developer.log(
      'GET $uri',
      name: 'SyncRemoteDataSource',
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 401) {
        throw const AuthException(
          message: 'Access token expired during pull sync',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ServerException(
          message: 'Pull sync API returned ${response.statusCode}: '
              '${response.body}',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SyncPullResponseModel.fromJson(json);
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Network error during pull sync: $e',
      );
    }
  }
}

