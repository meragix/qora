import 'dart:typed_data';

/// Pure stateless utility that splits and joins large payloads into byte chunks.
///
/// ## Why 80 KB per chunk?
///
/// [defaultChunkSize] = 80 KB balances:
/// - **VM limits**: stays well under the ~10 MB extension response ceiling.
/// - **Latency**: each chunk fits in a single VM service round-trip (~1–5 ms).
/// - **Base64 overhead**: 80 KB binary → ≈ 107 KB ASCII, safe for JSON transport.
///
/// Lower the chunk size via [LazyPayloadManager.chunkSize] only if individual
/// responses time out in your environment.
///
/// ## Stateless design
///
/// [PayloadChunker] has no state — it operates on raw byte arrays. Storage
/// lifecycle (IDs, TTL, LRU) is entirely managed by [PayloadStore].
abstract final class PayloadChunker {
  /// Default chunk size in bytes (80 KB).
  ///
  /// Override via [LazyPayloadManager.chunkSize] at construction time.
  static const int defaultChunkSize = 80 * 1024;

  /// Splits [bytes] into fixed-size [Uint8List] chunks of at most [chunkSize].
  ///
  /// The last chunk may be smaller than [chunkSize] when `bytes.length` is not
  /// a multiple of [chunkSize]. Returns an empty list for empty input.
  ///
  /// Throws [ArgumentError] when [chunkSize] ≤ 0.
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

  /// Concatenates [chunks] back into a single contiguous byte buffer.
  ///
  /// Uses [BytesBuilder] with `copy: false` for zero-copy assembly where
  /// possible. Call this after all chunks have been received and base64-decoded
  /// on the DevTools UI side.
  static Uint8List join(List<Uint8List> chunks) {
    final buffer = BytesBuilder(copy: false);
    for (final chunk in chunks) {
      buffer.add(chunk);
    }
    return buffer.takeBytes();
  }
}
