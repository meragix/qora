import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// View-model for the Query Inspector panel.
///
/// Derived from a [QueryEvent] snapshot; exposes computed fields that the
/// inspector panel renders directly — status badge, data preview, fetch
/// duration, large-payload flag, and metadata rows.
class QueryDetail {
  /// Human-readable query status: `'success'`, `'loading'`, `'error'`, etc.
  final String status;

  /// Truncated string representation of the cached data, or `null` if empty.
  final String? dataPreview;

  /// `true` when the payload exceeded the inline threshold; pull via chunks.
  final bool hasLargePayload;

  /// Wall-clock fetch duration in milliseconds, or `null` when not available.
  final int? fetchDurationMs;

  /// Timestamp at which this event was recorded.
  final DateTime fetchedAt;

  const QueryDetail({
    required this.status,
    this.dataPreview,
    this.hasLargePayload = false,
    this.fetchDurationMs,
    required this.fetchedAt,
  });

  /// Builds a [QueryDetail] from the latest [QueryEvent] snapshot.
  factory QueryDetail.fromEvent(QueryEvent event) {
    final rawData = event.data;
    final preview = rawData != null ? _truncate(rawData.toString(), max: 300) : null;

    return QueryDetail(
      status: event.status ?? 'unknown',
      dataPreview: preview,
      hasLargePayload: event.hasLargePayload,
      fetchDurationMs: event.fetchDurationMs,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(event.timestampMs),
    );
  }

  static String _truncate(String s, {required int max}) =>
      s.length > max ? '${s.substring(0, max)}…' : s;
}
