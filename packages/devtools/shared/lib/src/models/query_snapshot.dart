/// Immutable view of a cached query used by DevTools screens.
///
/// A [QuerySnapshot] is a lightweight DTO extracted from the live
/// `QoraClient` cache. It represents the state of one query at the moment
/// `ext.qora.getCacheSnapshot` was called.
///
/// ## Large payload handling
///
/// When the cached data exceeds the inline threshold (~80 KB), [data] is
/// `null` and [hasLargePayload] is `true`. The DevTools UI should:
/// 1. Display [summary] immediately (counts, approximate bytes).
/// 2. Pull the full payload on user demand via `ext.qora.getPayloadChunk`
///    using [payloadId] and [totalChunks].
///
/// See [QueryEvent] for the same pattern applied to streamed events.
final class QuerySnapshot {
  /// Stable query key as serialised by the runtime.
  final String key;

  /// Runtime query status string.
  ///
  /// Common values: `'idle'`, `'loading'`, `'success'`, `'error'`.
  final String status;

  /// Inlined payload for small results only.
  ///
  /// `null` when [hasLargePayload] is `true` — use [payloadId] instead.
  final Object? data;

  /// Unix epoch milliseconds of the last successful cache update.
  final int updatedAtMs;

  /// `true` when [data] exceeds the inline size limit and must be pulled in
  /// chunks via `ext.qora.getPayloadChunk`.
  final bool hasLargePayload;

  /// Opaque server-side identifier for lazy chunk pulling.
  ///
  /// Only set when [hasLargePayload] is `true`. Expires on the runtime after
  /// ~30 seconds ([PayloadStore] TTL).
  final String? payloadId;

  /// Total chunk count available for [payloadId].
  final int? totalChunks;

  /// Lightweight metadata shown in the cache inspector before payload is pulled.
  ///
  /// Typical fields: `approxBytes` (int), `itemCount` (int).
  final Map<String, Object?>? summary;

  /// Creates a query snapshot.
  const QuerySnapshot({
    required this.key,
    required this.status,
    required this.updatedAtMs,
    this.data,
    this.hasLargePayload = false,
    this.payloadId,
    this.totalChunks,
    this.summary,
  });

  /// Creates an instance from JSON.
  factory QuerySnapshot.fromJson(Map<String, Object?> json) {
    return QuerySnapshot(
      key: (json['key'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'unknown',
      data: json['data'],
      updatedAtMs: (json['updatedAtMs'] as int?) ?? 0,
      hasLargePayload: (json['hasLargePayload'] as bool?) ?? false,
      payloadId: json['payloadId'] as String?,
      totalChunks: json['totalChunks'] as int?,
      summary: (json['summary'] as Map<String, Object?>?) != null
          ? Map<String, Object?>.from(json['summary']! as Map)
          : null,
    );
  }

  /// Converts the snapshot to JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'key': key,
        'status': status,
        'data': data,
        'updatedAtMs': updatedAtMs,
        'hasLargePayload': hasLargePayload,
        'payloadId': payloadId,
        'totalChunks': totalChunks,
        'summary': summary,
      };
}
