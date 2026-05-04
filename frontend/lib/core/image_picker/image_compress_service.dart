import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Abstraction for image compression utilities.
///
/// Keeps `flutter_image_compress` plugin details out of
/// the domain / presentation layers.
abstract class ImageCompressService {
  /// Compresses [imageBytes] and returns the compressed result.
  ///
  /// [quality] ranges from 0–100 (default: 80).
  /// [minWidth] / [minHeight] set the output resolution bounds.
  Future<Uint8List> compress(
    Uint8List imageBytes, {
    int quality = 80,
    int minWidth = 1280,
    int minHeight = 1280,
  });
}

/// Default implementation backed by `flutter_image_compress`.
class ImageCompressServiceImpl implements ImageCompressService {
  const ImageCompressServiceImpl();

  @override
  Future<Uint8List> compress(
    Uint8List imageBytes, {
    int quality = 80,
    int minWidth = 1280,
    int minHeight = 1280,
  }) async {
    final result = await FlutterImageCompress.compressWithList(
      imageBytes,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
    );
    return result;
  }
}
