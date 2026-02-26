import 'qora_event.dart';

/// Enumerates query event subtypes emitted by the runtime.
enum QueryEventType {
  /// A query has been fetched successfully or with an error status.
  fetched,

  /// A query has been invalidated.
  invalidated,

  /// A query has been inserted into the cache.
  added,

  /// A query has been updated in-place.
  updated,

  /// A query has been removed from the cache.
  removed,
}

/// Typed protocol event for query lifecycle changes.
final class QueryEvent extends QoraEvent {
  /// Query event subtype.
  final QueryEventType type;

  /// Stable query key representation.
  final String key;

  /// Optional runtime status string (`loading`, `success`, `error`, ...).
  final String? status;

  /// Optional data payload (small payloads only).
  final Object? data;

  /// Indicates whether the actual payload should be fetched in chunks.
  final bool hasLargePayload;

  /// Opaque payload identifier used for lazy loading.
  final String? payloadId;

  /// Number of chunks available for lazy payload retrieval.
  final int? totalChunks;

  /// Optional lightweight summary of the payload.
  final Map<String, Object?>? summary;

  /// Creates a query event.
  QueryEvent({
    required super.eventId,
    required super.timestampMs,
    required this.type,
    required this.key,
    this.status,
    this.data,
    this.hasLargePayload = false,
    this.payloadId,
    this.totalChunks,
    this.summary,
  }) : super(kind: 'query.${type.name}');

  /// Helper constructor for `query.fetched`.
  factory QueryEvent.fetched({
    required String key,
    Object? data,
    Object? status,
    bool hasLargePayload = false,
    String? payloadId,
    int? totalChunks,
    Map<String, Object?>? summary,
  }) {
    return QueryEvent(
      eventId: QoraEvent.generateId(),
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      type: QueryEventType.fetched,
      key: key,
      status: status?.toString(),
      data: data,
      hasLargePayload: hasLargePayload,
      payloadId: payloadId,
      totalChunks: totalChunks,
      summary: summary,
    );
  }

  /// Helper constructor for `query.invalidated`.
  factory QueryEvent.invalidated({required String key}) {
    return QueryEvent(
      eventId: QoraEvent.generateId(),
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      type: QueryEventType.invalidated,
      key: key,
    );
  }

  /// Deserializes a query event.
  factory QueryEvent.fromJson(Map<String, Object?> json) {
    final rawKind = (json['kind'] as String?) ?? 'query.updated';
    final kindSuffix = rawKind.startsWith('query.') ? rawKind.substring('query.'.length) : rawKind;
    final type = QueryEventType.values.firstWhere(
      (value) => value.name == kindSuffix,
      orElse: () => QueryEventType.updated,
    );

    return QueryEvent(
      eventId: (json['eventId'] as String?) ?? QoraEvent.generateId(),
      timestampMs: (json['timestampMs'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      type: type,
      key: (json['queryKey'] as String?) ?? '',
      status: json['status'] as String?,
      data: json['data'],
      hasLargePayload: (json['hasLargePayload'] as bool?) ?? false,
      payloadId: json['payloadId'] as String?,
      totalChunks: json['totalChunks'] as int?,
      summary: (json['summary'] as Map<String, Object?>?) != null
          ? Map<String, Object?>.from(json['summary']! as Map)
          : null,
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'kind': kind,
        'timestampMs': timestampMs,
        'queryKey': key,
        'status': status,
        'data': data,
        'hasLargePayload': hasLargePayload,
        'payloadId': payloadId,
        'totalChunks': totalChunks,
        'summary': summary,
      };
}
