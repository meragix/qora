import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// View-model for the Query Inspector panel.
///
/// Derived from a [QueryEvent] snapshot; exposes computed fields that the
/// inspector panel renders directly — query key, status, cached data,
/// and cache timing metadata (updatedAt, staleAt, cacheTime, observers).
class QueryDetail {
  /// Serialised query key (e.g. `'["user","42"]'`).
  final String key;

  /// Human-readable query status: `'success'`, `'loading'`, `'error'`, etc.
  final String status;

  /// Raw cached data for the JSON viewer.
  final Object? data;

  /// Truncated string representation for quick preview.
  final String? dataPreview;

  /// `true` when the payload exceeded the inline threshold.
  final bool hasLargePayload;

  /// Wall-clock fetch duration in milliseconds, or `null` when not available.
  final int? fetchDurationMs;

  /// Timestamp when this query key was first observed by the tracker.
  /// `null` when not provided by the event (e.g. for very first events before
  /// the tracker recorded it).
  final DateTime? createdAt;

  /// Timestamp at which data was last fetched.
  final DateTime updatedAt;

  /// Timestamp after which data is considered stale, or `null` if never stale.
  final DateTime? staleAt;

  /// Cache time (GC delay after last unsubscribe) in milliseconds.
  final int? cacheTimeMs;

  /// Number of active observers at the time of the last fetch.
  final int observerCount;

  /// Configured maximum retry count from [QoraOptions.retryCount], or `null`
  /// when not provided by the event (e.g. non-fetch events).
  final int? retryCount;

  /// The type of the last event received for this query.
  final QueryEventType eventType;

  /// Sticky invalidated flag managed by [QueryInspectorNotifier].
  ///
  /// Remains `true` even after the invalidate triggers an immediate refetch
  /// (which would overwrite [eventType]). Cleared only when a non-loading
  /// fetch result arrives.
  final bool isInvalidated;

  const QueryDetail({
    required this.key,
    required this.status,
    this.data,
    this.dataPreview,
    this.hasLargePayload = false,
    this.fetchDurationMs,
    this.createdAt,
    required this.updatedAt,
    this.staleAt,
    this.cacheTimeMs,
    this.observerCount = 0,
    this.retryCount,
    this.eventType = QueryEventType.updated,
    this.isInvalidated = false,
  });

  /// Builds a [QueryDetail] from the latest [QueryEvent] snapshot.
  factory QueryDetail.fromEvent(QueryEvent event,
      {bool isInvalidated = false}) {
    final rawData = event.data;
    final preview = rawData?.toString().truncate(max: 300);
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(event.timestampMs);
    final staleAt = event.staleTimeMs != null && event.staleTimeMs! > 0
        ? updatedAt.add(Duration(milliseconds: event.staleTimeMs!))
        : null;

    return QueryDetail(
      key: event.key,
      status: event.status.orDefault('unknown'),
      data: rawData,
      dataPreview: preview,
      hasLargePayload: event.hasLargePayload,
      fetchDurationMs: event.fetchDurationMs,
      createdAt: event.createdAtMs!.toNullOrDateTime(),
      updatedAt: updatedAt,
      staleAt: staleAt,
      cacheTimeMs: event.gcTimeMs,
      observerCount: event.observerCount,
      retryCount: event.retryCount,
      eventType: event.type,
      isInvalidated: isInvalidated,
    );
  }
}
