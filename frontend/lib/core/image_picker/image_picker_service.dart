import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Data class representing a picked image with its metadata.
class PickedImageData {
  /// Raw bytes of the image.
  final Uint8List bytes;

  /// Original file name (e.g. 'IMG_20260504.jpg').
  final String fileName;

  /// MIME type if available (e.g. 'image/jpeg').
  final String? mimeType;

  const PickedImageData({
    required this.bytes,
    required this.fileName,
    this.mimeType,
  });

  /// Size of the image in bytes.
  int get sizeInBytes => bytes.length;

  /// Size of the image in megabytes.
  double get sizeInMB => sizeInBytes / (1024 * 1024);
}

/// Abstraction over the platform's image picker capability.
///
/// This service wraps `image_picker` so that the rest of the app
/// (Cubits, UseCases) depends on an interface rather than a concrete
/// Flutter plugin. This makes testing easier and keeps plugin details
/// out of business logic layers.
abstract class ImagePickerService {
  /// Opens the device camera for the user to capture a photo.
  ///
  /// Returns `null` if the user cancels.
  Future<PickedImageData?> pickFromCamera({
    int imageQuality = 90,
    double maxWidth = 1920,
    double maxHeight = 1920,
  });

  /// Opens the device gallery for the user to select a photo.
  ///
  /// Returns `null` if the user cancels.
  Future<PickedImageData?> pickFromGallery({
    int imageQuality = 90,
    double maxWidth = 1920,
    double maxHeight = 1920,
  });

  /// Convenience method — picks from either source.
  Future<PickedImageData?> pickImage({
    required ImageSource source,
    int imageQuality = 90,
    double maxWidth = 1920,
    double maxHeight = 1920,
  });
}

/// Default implementation backed by the `image_picker` plugin.
class ImagePickerServiceImpl implements ImagePickerService {
  final ImagePicker _picker;

  ImagePickerServiceImpl({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  @override
  Future<PickedImageData?> pickFromCamera({
    int imageQuality = 90,
    double maxWidth = 1920,
    double maxHeight = 1920,
  }) =>
      pickImage(
        source: ImageSource.camera,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

  @override
  Future<PickedImageData?> pickFromGallery({
    int imageQuality = 90,
    double maxWidth = 1920,
    double maxHeight = 1920,
  }) =>
      pickImage(
        source: ImageSource.gallery,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

  @override
  Future<PickedImageData?> pickImage({
    required ImageSource source,
    int imageQuality = 90,
    double maxWidth = 1920,
    double maxHeight = 1920,
  }) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );

    if (xFile == null) return null;

    final bytes = await xFile.readAsBytes();
    return PickedImageData(
      bytes: bytes,
      fileName: xFile.name,
      mimeType: xFile.mimeType,
    );
  }
}
