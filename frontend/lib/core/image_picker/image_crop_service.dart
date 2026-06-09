import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

/// Abstraction over the image cropping capability.
///
/// Wraps the `image_cropper` plugin so that business logic layers
/// (Cubits, UseCases) depend on an interface, not the Flutter plugin
/// directly. This improves testability and keeps platform details
/// out of domain code.
abstract class ImageCropService {
  /// Opens the system crop UI for the image at [sourcePath].
  ///
  /// Returns the cropped image as [Uint8List], or `null` if the user
  /// cancels the crop operation.
  ///
  /// [themeData] is used to style the crop UI to match the app theme.
  Future<Uint8List?> cropImage({
    required String sourcePath,
    ThemeData? themeData,
  });
}

/// Default implementation backed by the `image_cropper` plugin.
///
/// Uses `ImageCropper().cropImage()` which delegates to:
/// - **Android**: UCrop (native activity — requires AndroidManifest entry)
/// - **iOS**: TOCropViewController (built-in)
class ImageCropServiceImpl implements ImageCropService {
  final ImageCropper _cropper;

  ImageCropServiceImpl({ImageCropper? cropper})
    : _cropper = cropper ?? ImageCropper();

  @override
  Future<Uint8List?> cropImage({
    required String sourcePath,
    ThemeData? themeData,
  }) async {
    final primaryColor = themeData?.colorScheme.primary ?? Colors.blue;
    final backgroundColor = themeData?.scaffoldBackgroundColor ?? Colors.black;
    final toolbarColor = themeData?.colorScheme.surface ?? Colors.black;
    final toolbarWidgetColor = themeData?.colorScheme.onSurface ?? Colors.white;

    final croppedFile = await _cropper.cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Chọn vùng văn bản',
          toolbarColor: toolbarColor,
          toolbarWidgetColor: toolbarWidgetColor,
          activeControlsWidgetColor: primaryColor,
          backgroundColor: backgroundColor,
          statusBarLight: true,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Chọn vùng văn bản',
          doneButtonTitle: 'Xong',
          cancelButtonTitle: 'Huỷ',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );

    if (croppedFile == null) return null;

    // Read the cropped file bytes and clean up the temp file.
    final file = File(croppedFile.path);
    final bytes = await file.readAsBytes();
    if (croppedFile.path != sourcePath && await file.exists()) {
      await file.delete();
    }
    return bytes;
  }
}
