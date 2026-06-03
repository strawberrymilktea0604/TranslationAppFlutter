import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:frontend/core/error/exceptions.dart';

// ---------------------------------------------------------------------------
// Result model
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class OcrRemoteDataSource {
  /// Uploads [imageBytes] to `POST /api/v1/images/translate`.
  ///
  /// Calls [onProgress] with values from 0.0 → 1.0 while the bytes are
  /// being streamed to the server.  Values above 1.0 indicate the server
  /// is processing (OCR stage).
  ///
  /// Throws [ServerException] on non-200 responses or timeout.
  Future<OcrResultData> translateImage({
    required Uint8List imageBytes,
    required String filename,
    required String sourceLanguage,
    required String targetLanguage,
    String? authToken,
    required void Function(double progress) onProgress,
  });
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

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
      // Build a MultipartRequest so we can finalize and track its byte stream.
      final multipart = http.MultipartRequest('POST', uri);

      if (authToken != null) {
        multipart.headers['Authorization'] = 'Bearer $authToken';
      }

      multipart.fields['source_language'] = sourceLanguage;
      multipart.fields['target_language'] = targetLanguage;
      multipart.fields['optimize_image'] = 'true';

      multipart.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      );

      // Finalize and get the raw byte stream + total content length.
      final byteStream = multipart.finalize();
      final totalBytes = multipart.contentLength;

      // Wrap the byte stream to track upload progress.
      int sentBytes = 0;
      final trackedStream = byteStream.map((chunk) {
        sentBytes += chunk.length;
        if (totalBytes > 0) {
          // Upload is 0.0–0.9; OCR/translate phase is indicated by 1.0+
          onProgress((sentBytes / totalBytes).clamp(0.0, 0.9));
        }
        return chunk;
      });

      // Build a StreamedRequest with our tracked stream.
      final streamedRequest = http.StreamedRequest('POST', uri);
      streamedRequest.headers.addAll(multipart.headers);
      streamedRequest.contentLength = totalBytes;

      trackedStream.listen(
        streamedRequest.sink.add,
        onDone: streamedRequest.sink.close,
        onError: (Object e) => streamedRequest.sink.addError(e),
        cancelOnError: true,
      );

      // Signal that upload is done and server is processing.
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

      // Error response
      String detail = 'Lỗi máy chủ (${streamedResponse.statusCode})';
      try {
        final errJson = jsonDecode(responseBody) as Map<String, dynamic>;
        detail = (errJson['detail'] as String?) ?? detail;

        // Translate common backend errors to Vietnamese
        if (detail == 'No text could be extracted from image') {
          detail = 'Không tìm thấy chữ trong ảnh. Hãy thử ảnh khác.';
        }
      } catch (_) {}

      throw ServerException(message: detail);
    } on ServerException {
      rethrow;
    } on TimeoutException {
      throw ServerException(message: 'Quá thời gian chờ. Hãy thử lại.');
    } catch (e) {
      throw ServerException(message: 'Không thể kết nối: ${e.toString()}');
    }
  }
}
