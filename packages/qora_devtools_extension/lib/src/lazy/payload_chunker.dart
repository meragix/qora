import 'dart:typed_data';

/// Utility that splits/joins large payloads into transport-safe byte chunks.
abstract final class PayloadChunker {
  /// Default chunk size used by the extension protocol.
  static const int defaultChunkSize = 80 * 1024;

  /// Splits [bytes] into fixed-size chunks.
  static List<Uint8List> split(
    List<int> bytes, {
    int chunkSize = defaultChunkSize,
  }) {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'Must be > 0');
    }

    if (bytes.isEmpty) {
      return const <Uint8List>[];
    }

    final chunks = <Uint8List>[];
    for (var start = 0; start < bytes.length; start += chunkSize) {
      final end =
          (start + chunkSize < bytes.length) ? start + chunkSize : bytes.length;
      chunks.add(Uint8List.fromList(bytes.sublist(start, end)));
    }
    return chunks;
  }

  /// Concatenates [chunks] back into a single byte buffer.
  static Uint8List join(List<Uint8List> chunks) {
    final buffer = BytesBuilder(copy: false);
    for (final chunk in chunks) {
      buffer.add(chunk);
    }
    return buffer.takeBytes();
  }
}
