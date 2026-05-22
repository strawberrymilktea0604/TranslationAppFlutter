import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../../../../core/error/exceptions.dart';
import '../models/sync_model.dart';

/// Remote data source for the sync feature.
///
/// Calls `POST /api/v1/sync/vocabulary` to push unsynced
/// vocabulary records to the backend.
abstract class SyncRemoteDataSource {
  /// Sends a batch of unsynced vocabulary items to the server.
  ///
  /// Throws [ServerException] on non-2xx responses.
  /// Throws [AuthException] on 401 (token expired).
  Future<SyncResponseModel> syncVocabulary({
    required SyncVocabularyRequestModel request,
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
}
