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

  /// Timestamp at which data was last fetched.
  final DateTime updatedAt;

  /// Timestamp after which data is considered stale, or `null` if never stale.
  final DateTime? staleAt;

  /// Cache time (GC delay after last unsubscribe) in milliseconds.
  final int? cacheTimeMs;

  /// Number of active observers at the time of the last fetch.
  final int observerCount;

  const QueryDetail({
    required this.key,
    required this.status,
    this.data,
    this.dataPreview,
    this.hasLargePayload = false,
    this.fetchDurationMs,
    required this.updatedAt,
    this.staleAt,
    this.cacheTimeMs,
    this.observerCount = 0,
  });

  /// Builds a [QueryDetail] from the latest [QueryEvent] snapshot.
  factory QueryDetail.fromEvent(QueryEvent event) {
    final rawData = event.data;
    final preview = rawData != null ? _truncate(rawData.toString(), max: 300) : null;
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(event.timestampMs);
    final staleAt = event.staleTimeMs != null && event.staleTimeMs! > 0
        ? updatedAt.add(Duration(milliseconds: event.staleTimeMs!))
        : null;

    return QueryDetail(
      key: event.key,
      status: event.status ?? 'unknown',
      data: rawData,
      dataPreview: preview,
      hasLargePayload: event.hasLargePayload,
      fetchDurationMs: event.fetchDurationMs,
      updatedAt: updatedAt,
      staleAt: staleAt,
      cacheTimeMs: event.gcTimeMs,
      observerCount: event.observerCount,
    );
  }

  static String _truncate(String s, {required int max}) =>
      s.length > max ? '${s.substring(0, max)}…' : s;
}
