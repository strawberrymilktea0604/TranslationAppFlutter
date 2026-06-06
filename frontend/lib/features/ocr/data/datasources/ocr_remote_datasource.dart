import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:frontend/core/error/exceptions.dart';

class OcrResultData {
  final String extractedText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double? confidence;

  const OcrResultData({
    required this.extractedText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.confidence,
  });
}

abstract class OcrRemoteDataSource {
  Future<OcrResultData> translateImage({
    required Uint8List imageBytes,
    required String filename,
    required String sourceLanguage,
    required String targetLanguage,
    String? authToken,
    required void Function(double progress) onProgress,
  });
}

class OcrRemoteDataSourceImpl implements OcrRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  static const _timeout = Duration(seconds: 60);

  const OcrRemoteDataSourceImpl({required this.client, required this.baseUrl});

  @override
  Future<OcrResultData> translateImage({
    required Uint8List imageBytes,
    required String filename,
    required String sourceLanguage,
    required String targetLanguage,
    String? authToken,
    required void Function(double progress) onProgress,
  }) async {
    final uri = Uri.parse('$baseUrl/images/translate');

    try {
      final multipart = http.MultipartRequest('POST', uri);

      if (authToken != null && authToken.isNotEmpty) {
        multipart.headers['Authorization'] = 'Bearer $authToken';
      }

      multipart.fields['source_language'] = sourceLanguage;
      multipart.fields['target_language'] = targetLanguage;
      multipart.fields['optimize_image'] = 'true';
      multipart.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      );

      final byteStream = multipart.finalize();
      final totalBytes = multipart.contentLength;

      int sentBytes = 0;
      final trackedStream = byteStream.map((chunk) {
        sentBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress((sentBytes / totalBytes).clamp(0.0, 0.9));
        }
        return chunk;
      });

      final streamedRequest = http.StreamedRequest('POST', uri);
      streamedRequest.headers.addAll(multipart.headers);
      streamedRequest.contentLength = totalBytes;

      trackedStream.listen(
        streamedRequest.sink.add,
        onDone: streamedRequest.sink.close,
        onError: streamedRequest.sink.addError,
        cancelOnError: true,
      );

      onProgress(1.0);

      final streamedResponse = await client
          .send(streamedRequest)
          .timeout(_timeout);

      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>;

        return OcrResultData(
          extractedText: (data['source_text'] as String?) ?? '',
          translatedText: (data['translated_text'] as String?) ?? '',
          sourceLanguage:
              (data['source_language'] as String?) ?? sourceLanguage,
          targetLanguage:
              (data['target_language'] as String?) ?? targetLanguage,
          confidence: (data['ocr_confidence'] as num?)?.toDouble(),
        );
      }

      throw ServerException(
        message: _extractErrorMessage(responseBody, streamedResponse.statusCode),
        statusCode: streamedResponse.statusCode,
      );
    } on ServerException {
      rethrow;
    } on TimeoutException {
      throw const ServerException(
        message: 'Yêu cầu mất quá lâu. Vui lòng thử lại.',
        statusCode: 408,
      );
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    } catch (e) {
      throw ServerException(message: 'Không thể xử lý ảnh: ${e.toString()}');
    }
  }

  String _extractErrorMessage(String responseBody, int statusCode) {
    try {
      final errJson = jsonDecode(responseBody) as Map<String, dynamic>;
      final detail = errJson['detail'];
      if (detail == 'No text could be extracted from image') {
        return 'Không tìm thấy chữ trong ảnh. Hãy thử ảnh khác.';
      }
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
      if (detail is Map<String, dynamic>) {
        return detail['message'] as String? ?? _fallbackErrorMessage(statusCode);
      }
    } catch (_) {}
    return _fallbackErrorMessage(statusCode);
  }

  String _fallbackErrorMessage(int statusCode) {
    if (statusCode == 401) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (statusCode == 413) {
      return 'Ảnh quá lớn. Vui lòng chọn ảnh nhỏ hơn.';
    }
    if (statusCode >= 500) {
      return 'Dịch vụ AI đang gặp sự cố. Vui lòng thử lại sau ít phút.';
    }
    return 'Không thể dịch ảnh lúc này. Vui lòng thử lại.';
  }
}
