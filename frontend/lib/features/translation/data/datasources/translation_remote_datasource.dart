import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/translation/data/models/translation_model.dart';

/// Abstract interface for remote translation API.
abstract class TranslationRemoteDataSource {
  /// Calls `POST /api/v1/translate/text`.
  Future<TranslationModel> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? authToken,
  });
}

class TranslationRemoteDataSourceImpl implements TranslationRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  static const _timeout = Duration(seconds: 12);

  const TranslationRemoteDataSourceImpl({
    required this.client,
    required this.baseUrl,
  });

  @override
  Future<TranslationModel> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? authToken,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    late final http.Response response;
    try {
      response = await client
          .post(
            Uri.parse('$baseUrl/translate/text'),
            headers: headers,
            body: jsonEncode({
              'text': text,
              'source_language': sourceLanguage,
              'target_language': targetLanguage,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const ServerException(
        message: 'Yêu cầu mất quá lâu. Vui lòng thử lại.',
        statusCode: 408,
      );
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? body;
      return TranslationModel.fromJson(data);
    }

    final errorMessage = _extractErrorMessage(response);
    throw ServerException(
      message: errorMessage,
      statusCode: response.statusCode,
    );
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is Map<String, dynamic>) {
          return detail['message'] as String? ??
              _fallbackErrorMessage(response.statusCode);
        }
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
      }
    } catch (_) {}
    return _fallbackErrorMessage(response.statusCode);
  }

  String _fallbackErrorMessage(int statusCode) {
    if (statusCode == 401) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (statusCode >= 500) {
      return 'Dịch vụ AI đang gặp sự cố. Vui lòng thử lại sau ít phút.';
    }
    return 'Không thể dịch lúc này. Vui lòng thử lại.';
  }
}
