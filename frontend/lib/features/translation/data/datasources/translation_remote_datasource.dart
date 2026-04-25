import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/translation/data/models/translation_model.dart';

/// Abstract interface for remote translation API.
abstract class TranslationRemoteDataSource {
  /// Calls `POST /api/v1/translate`.
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
          Uri.parse('$baseUrl/translate'),
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
      return TranslationModel.fromJson(body);
    }

    Map<String, dynamic> errorBody;
    try {
      errorBody = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      errorBody = {'detail': response.body};
    }

    throw ServerException(
      message:
          errorBody['detail'] as String? ??
          'Lỗi máy chủ ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }
}
