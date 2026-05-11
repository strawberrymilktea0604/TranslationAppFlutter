import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:frontend/core/error/exceptions.dart';

// ---------------------------------------------------------------------------
// Result data class
// ---------------------------------------------------------------------------

/// Raw result from the backend `/api/v1/audio/translate/voice` endpoint.
class SpeechTranslationData {
  final String sourceText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double sttLanguageProbability;
  final bool isCached;
  final double responseTimeMs;

  const SpeechTranslationData({
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sttLanguageProbability,
    this.isCached = false,
    this.responseTimeMs = 0.0,
  });
}

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

/// Remote data source for voice translation (UC05).
///
/// Uploads recorded audio to `POST /api/v1/audio/translate/voice`
/// which performs audio preprocessing → STT → translation in a
/// single server round-trip.
abstract class SpeechRemoteDataSource {
  /// Uploads audio file at [audioFilePath] for STT + translation.
  ///
  /// Throws [ServerException] on non-200 responses or timeout.
  Future<SpeechTranslationData> translateVoice({
    required String audioFilePath,
    String? sourceLanguage,
    required String targetLanguage,
    String? authToken,
  });
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

class SpeechRemoteDataSourceImpl implements SpeechRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  /// Timeout for audio upload + STT + translation pipeline.
  /// Longer than text translation because audio processing takes time.
  static const _timeout = Duration(seconds: 30);

  const SpeechRemoteDataSourceImpl({
    required this.client,
    required this.baseUrl,
  });

  @override
  Future<SpeechTranslationData> translateVoice({
    required String audioFilePath,
    String? sourceLanguage,
    required String targetLanguage,
    String? authToken,
  }) async {
    final uri = Uri.parse('$baseUrl/audio/translate/voice');

    try {
      final request = http.MultipartRequest('POST', uri);

      // Attach auth token for User-level rate limits.
      if (authToken != null && authToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }

      // Form fields matching backend endpoint signature.
      if (sourceLanguage != null && sourceLanguage != 'auto') {
        request.fields['source_language'] = sourceLanguage;
      }
      request.fields['target_language'] = targetLanguage;

      // Attach audio file.
      final file = File(audioFilePath);
      if (!await file.exists()) {
        throw const ServerException(
          message: 'File ghi âm không tồn tại.',
        );
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFilePath,
          filename: audioFilePath.split(Platform.pathSeparator).last,
        ),
      );

      // Send request with timeout.
      final streamedResponse = await client
          .send(request)
          .timeout(_timeout);

      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final data = (json['data'] as Map<String, dynamic>?) ?? json;

        return SpeechTranslationData(
          sourceText: (data['source_text'] as String?) ?? '',
          translatedText: (data['translated_text'] as String?) ?? '',
          sourceLanguage: (data['source_language'] as String?) ?? '',
          targetLanguage: (data['target_language'] as String?) ?? '',
          sttLanguageProbability:
              (data['stt_language_probability'] as num?)?.toDouble() ?? 0.0,
          isCached: (data['is_cached'] as bool?) ?? false,
          responseTimeMs:
              (data['response_time_ms'] as num?)?.toDouble() ?? 0.0,
        );
      }

      // Parse error detail from backend response.
      String detail = 'Lỗi máy chủ (${streamedResponse.statusCode})';
      try {
        final errJson = jsonDecode(responseBody) as Map<String, dynamic>;
        final rawDetail = errJson['detail'];
        if (rawDetail is String) {
          detail = rawDetail;
        } else if (rawDetail is Map<String, dynamic>) {
          detail = (rawDetail['message'] as String?) ?? detail;
        }

        // Translate common backend errors to Vietnamese.
        if (detail.contains('No text could be extracted')) {
          detail = 'Không nhận diện được giọng nói. Hãy thử lại.';
        }
        if (detail.contains('Rate limit exceeded')) {
          detail = 'Vượt quá giới hạn yêu cầu. Vui lòng chờ.';
        }
      } catch (_) {}

      throw ServerException(
        message: detail,
        statusCode: streamedResponse.statusCode,
      );
    } on ServerException {
      rethrow;
    } on TimeoutException {
      throw const ServerException(
        message: 'Quá thời gian chờ phản hồi. Hãy thử lại.',
      );
    } catch (e) {
      throw ServerException(
        message: 'Không thể kết nối tới máy chủ: ${e.toString()}',
      );
    }
  }
}
