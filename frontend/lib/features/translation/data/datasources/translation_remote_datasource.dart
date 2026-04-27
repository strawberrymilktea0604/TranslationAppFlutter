import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/translation/data/models/translation_model.dart';

/// Abstract interface for remote translation API.
abstract class TranslationRemoteDataSource {
  /// Calls `POST /api/v1/translate/text`.
  /// Throws [ServerException] on non-200 responses or timeout.
  Future<TranslationModel> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });
}

class TranslationRemoteDataSourceImpl implements TranslationRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  const TranslationRemoteDataSourceImpl({
    required this.client,
    required this.baseUrl,
  });

  @override
  Future<TranslationModel> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final response = await client
        .post(
          Uri.parse('$baseUrl/translate/text'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'source_language': sourceLanguage,
            'target_language': targetLanguage,
          }),
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw const ServerException(
            message: 'Yêu cầu hết thời gian, vui lòng thử lại.',
          ),
        );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      // Backend wraps responses in SuccessResponse:
      // { "status": "success", "data": { ... } }
      final data = (body['data'] as Map<String, dynamic>?) ?? body;
      return TranslationModel.fromJson(data);
    }

    // Parse error detail from backend error response format:
    // { "detail": { "status": "error", "code": "...", "message": "..." } }
    // or { "detail": "simple string" }
    Map<String, dynamic> errorBody;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        errorBody = decoded;
      } else {
        errorBody = {'detail': response.body};
      }
    } catch (_) {
      errorBody = {'detail': response.body};
    }

    String errorMessage;
    final detail = errorBody['detail'];
    if (detail is Map<String, dynamic>) {
      errorMessage =
          detail['message'] as String? ??
          'Lỗi máy chủ ${response.statusCode}';
    } else if (detail is String) {
      errorMessage = detail;
    } else {
      errorMessage = 'Lỗi máy chủ ${response.statusCode}';
    }

    throw ServerException(
      message: errorMessage,
      statusCode: response.statusCode,
    );
  }
}
