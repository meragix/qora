import 'dart:convert';
import 'dart:math';

import 'payload_chunker.dart';
import 'payload_store.dart';

/// Orchestrates the lazy payload push/pull strategy for VM extension responses.
///
/// ## Problem
///
/// VM service `postEvent` payloads are limited to a few megabytes, and sending
/// large JSON objects (e.g. a list of 10 000 products) inline causes:
/// - VM service errors for oversized payloads,
/// - high memory pressure on both the app and DevTools sides,
/// - increased serialisation latency that blocks the event stream.
///
/// ## Solution — push metadata, pull data
///
/// 1. **Push** (via [VmEventPusher]): the event payload carries only metadata
///    (`hasLargePayload: true`, `payloadId`, `totalChunks`, `summary`).
/// 2. **Pull** (via `ext.qora.getPayloadChunk`): the DevTools UI retrieves
///    each base64-encoded 80 KB chunk on demand.
/// 3. **Reassembly**: the UI concatenates chunks and JSON-decodes the result.
///
/// ## Inline threshold
///
/// When the serialised size is ≤ [chunkSize], the payload is returned with
/// `hasLargePayload: false` — no storage occurs and the event carries the
/// full data inline (zero additional round-trips).
///
/// ## Memory management
///
/// Chunks are managed by [PayloadStore] which enforces:
/// - **TTL**: entries expire after 30 s — pull promptly.
/// - **LRU cap**: total bytes are bounded to 20 MB; oldest entries are evicted
///   when the budget is exceeded.
/// - **Explicit clear**: call [clear] when the `QoraClient` is disposed.
class LazyPayloadManager {
  /// Creates a lazy payload manager.
  ///
  /// [store] — injectable [PayloadStore]; defaults to a new instance with
  /// default TTL (30 s) and budget (20 MB).
  ///
  /// [chunkSize] — maximum bytes per chunk. Defaults to
  /// [PayloadChunker.defaultChunkSize] (80 KB). Reduce this value only if
  /// individual chunks cause VM service timeouts.
  LazyPayloadManager({
    PayloadStore? store,
    this.chunkSize = PayloadChunker.defaultChunkSize,
  }) : _store = store ?? PayloadStore();

  final PayloadStore _store;

  /// Maximum bytes per chunk (default 80 KB).
  ///
  /// Payloads whose serialised size is ≤ [chunkSize] are returned inline
  /// (`hasLargePayload: false`) — no storage is allocated.
  final int chunkSize;

  /// Serialises [data] and stores it in chunks if it exceeds [chunkSize].
  ///
  /// Returns a record with three fields:
  /// - `hasLargePayload` — `true` when chunks were created.
  /// - `payloadId` — opaque server-side ID (non-empty only when `hasLargePayload`).
  /// - `totalChunks` — number of chunks to pull (> 0 only when `hasLargePayload`).
  ///
  /// When `hasLargePayload` is `false`, the event can carry [data] inline and
  /// no `getPayloadChunk` call is required.
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

  /// Retrieves one base64-encoded chunk for [payloadId] at [chunkIndex].
  ///
  /// Returns a map ready to be passed to
  /// `ServiceExtensionResponse.result(jsonEncode(...))`. Fields:
  ///
  /// - `payloadId` — echoed for client-side validation.
  /// - `chunkIndex` — echoed for reassembly ordering.
  /// - `totalChunks` — total chunk count for this payload.
  /// - `encoding` — always `'base64'`.
  /// - `data` — base64-encoded chunk bytes.
  /// - `isLast` — `true` when this is the final chunk.
  ///
  /// Returns `{'error': 'expired_or_not_found'}` when the payload has expired
  /// (TTL elapsed) or was never stored.
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
