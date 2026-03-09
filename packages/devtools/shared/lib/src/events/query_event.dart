import 'qora_event.dart';

/// Enumerates query event subtypes emitted by the runtime.
///
/// The variant drives how the DevTools UI interprets the associated
/// [QueryEvent] — e.g. `fetched` may carry large payload metadata while
/// `invalidated` carries no data at all.
enum QueryEventType {
  /// A query has completed a fetch cycle (success or error).
  ///
  /// This is the most common event kind. For large results the data is not
  /// inlined — check [QueryEvent.hasLargePayload] and pull chunks via
  /// `ext.qora.getPayloadChunk`.
  fetched,

  /// A query has been marked stale and will be re-fetched on next access.
  invalidated,

  /// A new query key has been inserted into the cache.
  added,

  /// An existing cache entry has been updated in-place.
  updated,

  /// A cache entry has been evicted or explicitly removed.
  removed,
}

/// Typed protocol event for query lifecycle changes.
///
/// ## Lazy payload protocol
///
/// VM service extension payloads are limited to ~10 MB. For large query
/// results Qora uses a **push-metadata / pull-data** strategy:
///
/// 1. The runtime pushes a [QueryEvent] with [hasLargePayload] `= true`,
///    [payloadId], [totalChunks], and a [summary] (lightweight statistics).
/// 2. The DevTools UI detects `hasLargePayload` and pulls each chunk on
///    demand via `ext.qora.getPayloadChunk`.
/// 3. The UI reassembles the JSON from base64-encoded 80 KB chunks.
///
/// When [hasLargePayload] is `false`, [data] contains the full payload and
/// no additional pull is necessary.
///
/// ## Scaling note — summary field
///
/// [summary] is always populated regardless of payload size and provides a
/// lightweight preview (`approxBytes`, `itemCount`) that the cache inspector
/// can display without fetching the full payload. This minimises latency for
/// large cache panels with many simultaneous active queries.
final class QueryEvent extends QoraEvent {
  /// Query event subtype driving UI interpretation.
  final QueryEventType type;

  /// Stable query key as serialised by the runtime (e.g. `"todos?page=1"`).
  final String key;

  /// Optional runtime status string (`loading`, `success`, `error`, ...).
  ///
  /// `null` for events where status is irrelevant (e.g. `removed`).
  final String? status;

  /// Inlined payload for **small** results only.
  ///
  /// `null` when [hasLargePayload] is `true`. In that case use [payloadId]
  /// and [totalChunks] to pull the data in chunks.
  final Object? data;

  /// `true` when the payload exceeds the inline size threshold (~80 KB).
  ///
  /// When `true`, [payloadId] and [totalChunks] are set and [data] is `null`.
  final bool hasLargePayload;

  /// Opaque server-side identifier used to pull chunks from the runtime.
  ///
  /// Only set when [hasLargePayload] is `true`. Expires after 30 seconds on
  /// the runtime side ([PayloadStore] TTL) — pull all chunks promptly after
  /// receiving the event.
  final String? payloadId;

  /// Total number of base64-encoded chunks available for [payloadId].
  ///
  /// Only set when [hasLargePayload] is `true`.
  final int? totalChunks;

  /// Lightweight payload summary shown before the full data is pulled.
  ///
  /// Typical fields:
  /// - `approxBytes` (int) — approximate serialised size in bytes.
  /// - `itemCount` (int) — element count for lists and maps.
  ///
  /// May be `null` for non-data events such as `invalidated`.
  final Map<String, Object?>? summary;

  /// Wall-clock duration of the fetch in milliseconds, or `null` when not
  /// available (e.g. for `invalidated` events or infinite queries).
  ///
  /// Computed by [VmTracker] as the elapsed time between [onQueryFetching] and
  /// [onQueryFetched]. Use this to populate the Network Activity Monitor and
  /// Performance Metrics screens.
  final int? fetchDurationMs;

  /// Configured stale threshold in milliseconds (`null` = never stale,
  /// `0` = always stale). Used by DevTools to compute freshness indicators.
  final int? staleTimeMs;

  /// Cache time (GC delay after last subscriber unsubscribes) in milliseconds.
  /// Used by DevTools to show the "GC in …" countdown.
  final int? gcTimeMs;

  /// Number of active stream subscribers at the moment the fetch settled.
  /// Corresponds to how many widgets/consumers are watching this query.
  final int observerCount;

  /// Timestamp (ms since epoch) when this query key was first observed by the
  /// tracker. Populated by [OverlayTracker] / [VmTracker] from an internal
  /// first-seen map. `null` for events emitted by older runtimes.
  final int? createdAtMs;

  /// Configured maximum retry count from [QoraOptions.retryCount].
  ///
  /// `null` when not provided (e.g. for non-fetch events such as `invalidated`
  /// or `removed`). Used by DevTools to display the retry policy per query.
  final int? retryCount;

  /// Creates a query event.
  ///
  /// Prefer the named factories ([QueryEvent.fetched], [QueryEvent.invalidated])
  /// which auto-generate [eventId] and [timestampMs].
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
    this.fetchDurationMs,
    this.staleTimeMs,
    this.gcTimeMs,
    this.observerCount = 0,
    this.createdAtMs,
    this.retryCount,
  }) : super(kind: 'query.${type.name}');

  /// Helper constructor for `query.fetched`.
  ///
  /// Auto-generates [QoraEvent.eventId] and timestamps the event at call time.
  factory QueryEvent.fetched({
    required String key,
    Object? data,
    Object? status,
    bool hasLargePayload = false,
    String? payloadId,
    int? totalChunks,
    Map<String, Object?>? summary,
    int? fetchDurationMs,
    int? staleTimeMs,
    int? gcTimeMs,
    int observerCount = 0,
    int? createdAtMs,
    int? retryCount,
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
      fetchDurationMs: fetchDurationMs,
      staleTimeMs: staleTimeMs,
      gcTimeMs: gcTimeMs,
      observerCount: observerCount,
      createdAtMs: createdAtMs,
      retryCount: retryCount,
    );
  }

  /// Helper constructor for `query.invalidated`.
  ///
  /// Auto-generates [QoraEvent.eventId] and timestamps the event at call time.
  factory QueryEvent.invalidated({required String key}) {
    return QueryEvent(
      eventId: QoraEvent.generateId(),
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      type: QueryEventType.invalidated,
      key: key,
    );
  }

  /// Deserializes a query event from a raw JSON map.
  ///
  /// Tolerant of missing fields: falls back to sensible defaults so that
  /// partial payloads (e.g. emitted by an older runtime) do not throw.
  /// Unknown `kind` suffixes resolve to [QueryEventType.updated].
  factory QueryEvent.fromJson(Map<String, Object?> json) {
    final rawKind = (json['kind'] as String?) ?? 'query.updated';
    final kindSuffix = rawKind.startsWith('query.')
        ? rawKind.substring('query.'.length)
        : rawKind;
    final type = QueryEventType.values.firstWhere(
      (value) => value.name == kindSuffix,
      orElse: () => QueryEventType.updated,
    );

    return QueryEvent(
      eventId: (json['eventId'] as String?) ?? QoraEvent.generateId(),
      timestampMs: (json['timestampMs'] as int?) ??
          DateTime.now().millisecondsSinceEpoch,
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
      fetchDurationMs: json['fetchDurationMs'] as int?,
      staleTimeMs: json['staleTimeMs'] as int?,
      gcTimeMs: json['gcTimeMs'] as int?,
      observerCount: (json['observerCount'] as int?) ?? 0,
      createdAtMs: json['createdAtMs'] as int?,
      retryCount: json['retryCount'] as int?,
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
        'fetchDurationMs': fetchDurationMs,
        'staleTimeMs': staleTimeMs,
        'gcTimeMs': gcTimeMs,
        'observerCount': observerCount,
        'createdAtMs': createdAtMs,
        'retryCount': retryCount,
      };
}
