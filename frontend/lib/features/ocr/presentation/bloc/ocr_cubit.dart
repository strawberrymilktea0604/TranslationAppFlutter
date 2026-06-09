import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/core/error/app_error_message.dart';
import 'package:frontend/core/image_picker/image_picker_service.dart';
import 'package:frontend/core/image_picker/image_compress_service.dart';
import 'package:frontend/core/image_picker/image_crop_service.dart';
import 'package:frontend/features/ocr/domain/usecases/ocr_translate_usecase.dart';
import 'package:frontend/features/ocr/domain/usecases/retranslate_ocr_text_usecase.dart';
import 'package:frontend/features/history/domain/entities/history_entity.dart'
    as frontend_history;
import 'package:frontend/features/history/domain/repositories/history_repository.dart'
    as frontend_history;
import 'package:frontend/injection_container.dart';

part 'ocr_state.dart';

/// Cubit managing the OCR (image → crop → compress → upload → translate) pipeline.
///
/// Follows Clean Architecture:
///   UI → OcrCubit → OcrTranslateUseCase → OcrRepository → DataSource
///
/// Image picking, cropping and compression are handled through abstracted
/// services injected via constructor, keeping plugin details out of
/// business logic.
class OcrCubit extends Cubit<OcrState> {
  final OcrTranslateUseCase _ocrTranslateUseCase;
  final RetranslateOcrTextUseCase _retranslateUseCase;
  final ImagePickerService _imagePickerService;
  final ImageCompressService _imageCompressService;
  final ImageCropService _imageCropService;

  OcrCubit({
    required OcrTranslateUseCase ocrTranslateUseCase,
    required RetranslateOcrTextUseCase retranslateUseCase,
    required ImagePickerService imagePickerService,
    required ImageCompressService imageCompressService,
    required ImageCropService imageCropService,
  }) : _ocrTranslateUseCase = ocrTranslateUseCase,
       _retranslateUseCase = retranslateUseCase,
       _imagePickerService = imagePickerService,
       _imageCompressService = imageCompressService,
       _imageCropService = imageCropService,
       super(OcrInitial());

  // -------------------------------------------------------------------------
  // Step 1: Pick image from camera or gallery
  // -------------------------------------------------------------------------

  /// Picks an image from [source], then opens the crop UI to let the user
  /// select the text region, compresses the result, and uploads for
  /// OCR + translation.
  Future<void> pickAndProcess({
    required ImageSource source,
    required String srcLang,
    required String tgtLang,
    ThemeData? themeData,
  }) async {
    try {
      final picked = await _imagePickerService.pickImage(source: source);
      if (isClosed) return;
      if (picked == null) return; // User cancelled

      // --- Crop step: let user select the text region ---
      Uint8List imageBytes = picked.bytes;

      if (picked.filePath != null) {
        emit(OcrUploading(progress: 0.0, message: 'Đang mở khung cắt ảnh...'));

        final croppedBytes = await _imageCropService.cropImage(
          sourcePath: picked.filePath!,
          themeData: themeData,
        );
        if (isClosed) return;

        if (croppedBytes != null) {
          imageBytes = croppedBytes;
        }
        // If user cancels crop, proceed with original image.
      }

      await _compressAndUpload(
        imageBytes: imageBytes,
        srcLang: srcLang,
        tgtLang: tgtLang,
      );
    } catch (e) {
      if (!isClosed) {
        emit(OcrFailure(AppErrorMessage.fromError(e)));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Step 2: Compress (if needed) and upload
  // -------------------------------------------------------------------------

  /// Compresses [imageBytes] when > 1.5 MB, then uploads for OCR + translation.
  ///
  /// This is extracted as a separate method so it can be reused when
  /// the user skips or completes the crop step.
  Future<void> _compressAndUpload({
    required Uint8List imageBytes,
    required String srcLang,
    required String tgtLang,
  }) async {
    if (isClosed) return;
    emit(OcrUploading(progress: 0.0, message: 'Đang chuẩn bị ảnh...'));

    // Compress images > 1.5 MB to keep under the 5 MB server limit (§7.2).
    if (imageBytes.length > 1536 * 1024) {
      emit(OcrUploading(progress: 0.03, message: 'Đang nén ảnh...'));
      imageBytes = await _imageCompressService.compress(
        imageBytes,
        quality: 80,
        minWidth: 1280,
        minHeight: 1280,
      );
      if (isClosed) return;
    }

    final filename = 'lens_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await _ocrTranslateUseCase(
      OcrTranslateParams(
        imageBytes: imageBytes,
        filename: filename,
        sourceLanguage: srcLang,
        targetLanguage: tgtLang,
        onProgress: (p) {
          if (!isClosed) {
            if (p < 1.0) {
              emit(
                OcrUploading(
                  progress: p,
                  message: 'Đang tải ảnh lên... ${(p * 100).toInt()}%',
                ),
              );
            } else {
              emit(
                OcrUploading(progress: 1.0, message: 'Đang nhận diện chữ...'),
              );
            }
          }
        },
      ),
    );

    if (isClosed) return;

    result.fold(
      (failure) => emit(OcrFailure(AppErrorMessage.fromFailure(failure))),
      (entity) {
        if (entity.extractedText.trim().isEmpty) {
          emit(OcrFailure('Không tìm thấy chữ trong ảnh. Hãy thử ảnh khác.'));
          return;
        }
        emit(
          OcrSuccess(
            extractedText: entity.extractedText,
            translatedText: entity.translatedText,
            imageBytes: entity.imageBytes,
            sourceLang: entity.sourceLanguage,
            targetLang: entity.targetLanguage,
            confidence: entity.confidence,
          ),
        );

        // Lưu lịch sử
        try {
          final historyEntity = frontend_history.HistoryEntity(
            isarId: 0,
            id: 'local_${DateTime.now().millisecondsSinceEpoch}',
            sourceText: entity.extractedText,
            translatedText: entity.translatedText,
            sourceLanguage: entity.sourceLanguage,
            targetLanguage: entity.targetLanguage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isSynced: false,
          );
          sl<frontend_history.HistoryRepository>().saveHistory(historyEntity);
        } catch (_) {}
      },
    );
  }

  // -------------------------------------------------------------------------
  // Re-translate after user edits OCR text
  // -------------------------------------------------------------------------

  /// Re-translates user-edited OCR text without re-uploading the image.
  Future<void> retranslate({
    required String editedText,
    required Uint8List imageBytes,
    required String srcLang,
    required String tgtLang,
  }) async {
    if (isClosed) return;
    if (editedText.trim().isEmpty) return;

    emit(
      OcrRetranslating(
        editedText: editedText,
        imageBytes: imageBytes,
        sourceLang: srcLang,
        targetLang: tgtLang,
      ),
    );

    final result = await _retranslateUseCase(
      RetranslateParams(
        text: editedText.trim(),
        sourceLanguage: srcLang,
        targetLanguage: tgtLang,
      ),
    );

    if (isClosed) return;

    result.fold(
      (failure) => emit(OcrFailure(AppErrorMessage.fromFailure(failure))),
      (translation) {
        emit(
          OcrSuccess(
            extractedText: editedText,
            translatedText: translation.translatedText,
            imageBytes: imageBytes,
            sourceLang: translation.sourceLanguage,
            targetLang: translation.targetLanguage,
          ),
        );

        // Lưu lịch sử
        try {
          final historyEntity = frontend_history.HistoryEntity(
            isarId: 0,
            id: 'local_${DateTime.now().millisecondsSinceEpoch}',
            sourceText: editedText,
            translatedText: translation.translatedText,
            sourceLanguage: translation.sourceLanguage,
            targetLanguage: translation.targetLanguage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isSynced: false,
          );
          sl<frontend_history.HistoryRepository>().saveHistory(historyEntity);
        } catch (_) {}
      },
    );
  }

  /// Resets back to initial state.
  void reset() {
    if (!isClosed) {
      emit(OcrInitial());
    }
  }
}
