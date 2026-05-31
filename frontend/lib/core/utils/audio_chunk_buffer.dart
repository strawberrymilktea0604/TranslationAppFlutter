import 'dart:typed_data';

/// Utility class that accumulates raw PCM audio bytes and flushes
/// them in fixed-size chunks.
///
/// Extracted from [ConversationViewModel] so the ViewModel only
/// deals with domain-level audio operations, not byte-level
/// buffering.
///
/// Default chunk size = 2 seconds of PCM 16-bit mono @ 16 kHz:
///   16000 samples/s × 2 bytes/sample × 1 channel × 2 s = 64 000 bytes.
class AudioChunkBuffer {
  /// Number of bytes per output chunk.
  final int chunkSizeBytes;

  List<int> _buffer = [];

  /// Creates a buffer that flushes every [chunkSizeBytes] bytes.
  ///
  /// [chunkSizeBytes] defaults to 64 000 (2 s @ 16 kHz, mono, 16-bit).
  AudioChunkBuffer({this.chunkSizeBytes = 64000});

  /// Appends [data] to the internal buffer.
  ///
  /// Returns a list of ready-to-send chunks whose length equals
  /// [chunkSizeBytes]. May return an empty list if the buffer has
  /// not yet accumulated enough bytes.
  List<Uint8List> addAndFlush(Uint8List data) {
    _buffer.addAll(data);

    final chunks = <Uint8List>[];
    while (_buffer.length >= chunkSizeBytes) {
      chunks.add(Uint8List.fromList(_buffer.sublist(0, chunkSizeBytes)));
      _buffer = _buffer.sublist(chunkSizeBytes);
    }
    return chunks;
  }

  /// Returns any remaining bytes in the buffer (less than
  /// [chunkSizeBytes]) and clears the buffer.
  ///
  /// Returns `null` if the buffer is empty.
  Uint8List? flushRemaining() {
    if (_buffer.isEmpty) return null;
    final remaining = Uint8List.fromList(_buffer);
    _buffer = [];
    return remaining;
  }

  /// Discards all buffered data.
  void clear() {
    _buffer = [];
  }

  /// Number of bytes currently buffered.
  int get length => _buffer.length;

  /// Whether the buffer contains any data.
  bool get isNotEmpty => _buffer.isNotEmpty;
}
