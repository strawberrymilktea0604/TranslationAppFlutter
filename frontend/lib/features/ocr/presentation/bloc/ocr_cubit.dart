import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/ocr/data/datasources/ocr_remote_datasource.dart';
import 'package:frontend/features/translation/data/datasources/translation_remote_datasource.dart';

part 'ocr_state.dart';

class OcrCubit extends Cubit<OcrState> {
  final OcrRemoteDataSource _ocrDataSource;
  final TranslationRemoteDataSource _translationDataSource;
  final AuthLocalDataSource _authLocalDataSource;
  final ImagePicker _picker = ImagePicker();

  OcrCubit({
    required OcrRemoteDataSource ocrDataSource,
    required TranslationRemoteDataSource translationDataSource,
    required AuthLocalDataSource authLocalDataSource,
  })  : _ocrDataSource = ocrDataSource,
        _translationDataSource = translationDataSource,
        _authLocalDataSource = authLocalDataSource,
        super(OcrInitial());

  // -------------------------------------------------------------------------
  // Pick image, upload, OCR + translate in one call
  // -------------------------------------------------------------------------

  Future<void> pickAndProcess({
    required ImageSource source,
    required String srcLang,
    required String tgtLang,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return; // User cancelled

      emit(OcrUploading(progress: 0.0, message: 'Đang chuẩn bị ảnh...'));

      // Read bytes
      Uint8List imageBytes = await picked.readAsBytes();

      // Compress if > 1.5 MB to save bandwidth
      if (imageBytes.length > 1536 * 1024) {
        emit(OcrUploading(progress: 0.03, message: 'Đang nén ảnh...'));
        final compressed = await FlutterImageCompress.compressWithList(
          imageBytes,
          quality: 80,
          minWidth: 1280,
          minHeight: 1280,
        );
        imageBytes = compressed;
      }

      final authToken = await _authLocalDataSource.getAccessToken();
      final filename = 'lens_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await _ocrDataSource.translateImage(
        imageBytes: imageBytes,
        filename: filename,
        sourceLanguage: srcLang,
        targetLanguage: tgtLang,
        authToken: authToken,
        onProgress: (p) {
          if (!isClosed) {
            if (p < 1.0) {
              emit(OcrUploading(
                progress: p,
                message: 'Đang tải ảnh lên... ${(p * 100).toInt()}%',
              ));
            } else {
              emit(OcrUploading(
                progress: 1.0,
                message: 'Đang nhận diện chữ...',
              ));
            }
          }
        },
      );

      if (isClosed) return;

      if (result.extractedText.trim().isEmpty) {
        emit(OcrFailure('Không tìm thấy chữ trong ảnh. Hãy thử ảnh khác.'));
        return;
      }

      emit(OcrSuccess(
        extractedText: result.extractedText,
        translatedText: result.translatedText,
        imageBytes: imageBytes,
        sourceLang: srcLang,
        targetLang: tgtLang,
        confidence: result.confidence,
      ));
    } catch (e) {
      if (!isClosed) {
        emit(OcrFailure(e.toString().replaceFirst('Exception: ', '')));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Re-translate after user edits OCR text
  // -------------------------------------------------------------------------

  Future<void> retranslate({
    required String editedText,
    required Uint8List imageBytes,
    required String srcLang,
    required String tgtLang,
  }) async {
    if (editedText.trim().isEmpty) return;

    // Keep image visible while re-translating
    emit(OcrRetranslating(
      editedText: editedText,
      imageBytes: imageBytes,
      sourceLang: srcLang,
      targetLang: tgtLang,
    ));

    try {
      final authToken = await _authLocalDataSource.getAccessToken();
      final translation = await _translationDataSource.translateText(
        text: editedText.trim(),
        sourceLanguage: srcLang == 'auto' ? 'en' : srcLang,
        targetLanguage: tgtLang,
        authToken: authToken,
      );

      if (!isClosed) {
        emit(OcrSuccess(
          extractedText: editedText,
          translatedText: translation.translatedText,
          imageBytes: imageBytes,
          sourceLang: srcLang,
          targetLang: tgtLang,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(OcrFailure('Không thể dịch lại: ${e.toString()}'));
      }
    }
  }

  void reset() => emit(OcrInitial());
}
