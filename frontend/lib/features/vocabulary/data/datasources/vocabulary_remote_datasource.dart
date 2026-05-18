import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../../../../core/error/exceptions.dart';

abstract class VocabularyRemoteDataSource {
  /// Fetches a paginated list of vocabularies from the server.
  Future<Map<String, dynamic>> getVocabularyList({
    required int page,
    required String accessToken,
  });
}

class VocabularyRemoteDataSourceImpl implements VocabularyRemoteDataSource {
  final http.Client _client;
  final String _baseUrl;

  VocabularyRemoteDataSourceImpl({
    required http.Client client,
    required String baseUrl,
  })  : _client = client,
        _baseUrl = baseUrl;

  @override
  Future<Map<String, dynamic>> getVocabularyList({
    required int page,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/vocabularies?page=$page&page_size=100');

    developer.log('GET $uri', name: 'VocabularyRemoteDataSource');

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 401) {
        throw const AuthException(message: 'Access token expired');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ServerException(
          message: 'Vocabulary API returned ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Network error: $e');
    }
  }
}
