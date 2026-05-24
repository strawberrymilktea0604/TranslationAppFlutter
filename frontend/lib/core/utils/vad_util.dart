import 'dart:math';
import 'dart:typed_data';

/// Utility class for Voice Activity Detection (VAD) and Volume calculation.
class VadUtil {
  /// Analyzes a chunk of PCM 16-bit audio data and calculates the normalized
  /// volume level (RMS amplitude) between 0.0 and 1.0.
  ///
  /// [chunk] must be PCM 16-bit little-endian audio data.
  static double calculateNormalizedVolume(Uint8List chunk) {
    if (chunk.isEmpty) return 0.0;

    // Convert Uint8List to Int16List to read 16-bit samples.
    final byteData = ByteData.view(chunk.buffer, chunk.offsetInBytes, chunk.length);
    final numSamples = chunk.length ~/ 2;
    
    if (numSamples == 0) return 0.0;

    double sumOfSquares = 0;
    for (int i = 0; i < numSamples; i++) {
      // PCM 16-bit little endian
      final sample = byteData.getInt16(i * 2, Endian.little);
      sumOfSquares += sample * sample;
    }

    final rms = sqrt(sumOfSquares / numSamples);
    
    // Max value of Int16 is 32768.
    // Normalized RMS is typically much smaller than the theoretical maximum,
    // so we scale it up a bit to make the UI more responsive.
    // 5000 is a reasonable heuristic for "loud speech".
    final normalized = (rms / 5000.0).clamp(0.0, 1.0);
    
    return normalized;
  }

  /// Determines if the given [volumeLevel] is considered "silence".
  /// 
  /// The [threshold] can be adjusted based on microphone sensitivity and noise.
  static bool isSilence(double volumeLevel, {double threshold = 0.05}) {
    return volumeLevel < threshold;
  }
}
