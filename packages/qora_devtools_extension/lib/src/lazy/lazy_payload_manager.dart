import 'dart:convert';
import 'dart:math';

import 'payload_chunker.dart';
import 'payload_store.dart';

/// Orchestrates lazy payload chunking and retrieval for VM extension responses.
class LazyPayloadManager {
  /// Creates a lazy payload manager.
  LazyPayloadManager({
    PayloadStore? store,
    this.chunkSize = PayloadChunker.defaultChunkSize,
  }) : _store = store ?? PayloadStore();

  final PayloadStore _store;

  /// Chunk size in bytes.
  final int chunkSize;

  /// Stores [data] as chunked JSON when it exceeds [chunkSize].
  ///
  /// Returns metadata consumed by the UI:
  /// - `hasLargePayload == false`: payload can be sent inline.
  /// - otherwise, use `payloadId` and `totalChunks` to pull chunks.
  ({String payloadId, int totalChunks, bool hasLargePayload}) store(
    Object? data,
  ) {
    final json = jsonEncode(data);
    final bytes = utf8.encode(json);

    if (bytes.length <= chunkSize) {
      return (payloadId: '', totalChunks: 0, hasLargePayload: false);
    }

    final payloadId = _generateId();
    final chunks = PayloadChunker.split(bytes, chunkSize: chunkSize);
    _store.put(payloadId, chunks);

    return (
      payloadId: payloadId,
      totalChunks: chunks.length,
      hasLargePayload: true,
    );
  }

  /// Retrieves one encoded chunk payload.
  ///
  /// The response map is ready to be wrapped in a
  /// `ServiceExtensionResponse.result(jsonEncode(...))`.
  Map<String, Object?> getChunk(String payloadId, int chunkIndex) {
    final chunk = _store.getChunk(payloadId, chunkIndex);
    final totalChunks = _store.chunkCount(payloadId);

    if (chunk == null || totalChunks == 0) {
      return <String, Object?>{'error': 'expired_or_not_found'};
    }

    return <String, Object?>{
      'payloadId': payloadId,
      'chunkIndex': chunkIndex,
      'totalChunks': totalChunks,
      'encoding': 'base64',
      'data': base64.encode(chunk),
      'isLast': chunkIndex == totalChunks - 1,
    };
  }

  /// Clears all stored payload chunks.
  void clear() => _store.clear();

  String _generateId() {
    final random = Random().nextInt(0x7fffffff).toRadixString(16);
    return 'pl_${DateTime.now().microsecondsSinceEpoch}_$random';
  }
}
