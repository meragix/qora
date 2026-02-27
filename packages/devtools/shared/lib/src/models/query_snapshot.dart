/// Immutable view of a cached query used by DevTools screens.
final class QuerySnapshot {
  /// Stable query key representation.
  final String key;

  /// Runtime query status (`idle`, `loading`, `success`, `error`, ...).
  final String status;

  /// Optional payload (small payloads only).
  final Object? data;

  /// Last update timestamp in unix epoch milliseconds.
  final int updatedAtMs;

  /// Indicates whether payload must be requested through chunk endpoint.
  final bool hasLargePayload;

  /// Opaque payload identifier for lazy loading.
  final String? payloadId;

  /// Number of chunks available for lazy loading.
  final int? totalChunks;

  /// Optional compact payload summary.
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
