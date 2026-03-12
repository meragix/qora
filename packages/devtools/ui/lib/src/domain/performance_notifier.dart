import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/usecases/observe_events.dart';

/// Aggregate statistics for a single query key.
class QueryStats {
  /// Creates stats for [key].
  QueryStats(this.key);

  /// String-serialised query key.
  final String key;

  /// Total number of completed fetches (success + error).
  int fetches = 0;

  /// Cumulative fetch duration in milliseconds.
  int totalDurationMs = 0;

  /// Number of fetches that ended with `'error'` status.
  int errors = 0;

  /// Unix epoch ms of the last completed fetch.
  int? lastFetchedAtMs;

  /// Average fetch duration in milliseconds.
  double get avgDurationMs => fetches == 0 ? 0 : totalDurationMs / fetches;

  /// Fraction of fetches that ended in error.
  double get errorRate => fetches == 0 ? 0 : errors / fetches;
}

/// Domain notifier that accumulates per-query performance statistics.
///
/// Subscribes to the live [QoraEvent] stream and aggregates:
/// - fetch count, cumulative duration, error count per query key
/// - global averages: total fetches, overall avg latency, overall error rate
///
/// ## Reset
///
/// Call [clear] to wipe all accumulated stats (e.g. after a hot restart or
/// when the DevTools tab is re-opened).
///
/// ## Sort
///
/// [sortedEntries] returns the per-query stats sorted by [SortField].
class PerformanceNotifier extends ChangeNotifier {
  /// Creates the notifier and subscribes to [observeEvents].
  PerformanceNotifier({required ObserveEventsUseCase observeEvents}) {
    _subscription = observeEvents().listen(_onEvent);
  }

  late final StreamSubscription<QoraEvent> _subscription;
  final Map<String, QueryStats> _stats = <String, QueryStats>{};

  /// All per-query stats, in no guaranteed order.
  Iterable<QueryStats> get allStats => _stats.values;

  /// Total completed fetch count across all queries.
  int get totalFetches => _stats.values.fold(0, (sum, s) => sum + s.fetches);

  /// Overall average fetch duration across all queries in milliseconds.
  double get overallAvgDurationMs {
    final total = _stats.values.fold(0, (sum, s) => sum + s.totalDurationMs);
    return totalFetches == 0 ? 0 : total / totalFetches;
  }

  /// Overall error rate across all queries (0.0–1.0).
  double get overallErrorRate {
    final errors = _stats.values.fold(0, (sum, s) => sum + s.errors);
    return totalFetches == 0 ? 0 : errors / totalFetches;
  }

  /// Number of unique query keys tracked.
  int get uniqueKeyCount => _stats.length;

  /// Returns per-query stats sorted by [field] descending.
  List<QueryStats> sortedEntries(SortField field) {
    final list = _stats.values.toList(growable: false);
    list.sort((a, b) {
      return switch (field) {
        SortField.fetches => b.fetches.compareTo(a.fetches),
        SortField.avgDuration => b.avgDurationMs.compareTo(a.avgDurationMs),
        SortField.errors => b.errors.compareTo(a.errors),
        SortField.lastActive =>
          (b.lastFetchedAtMs ?? 0).compareTo(a.lastFetchedAtMs ?? 0),
      };
    });
    return list;
  }

  void _onEvent(QoraEvent event) {
    if (event is! QueryEvent) return;
    final status = event.status;
    if (status == null || status == 'loading') return;

    final stats = _stats.putIfAbsent(event.key, () => QueryStats(event.key));
    stats.fetches++;
    if (event.fetchDurationMs != null) {
      stats.totalDurationMs += event.fetchDurationMs!;
    }
    if (status == 'error') stats.errors++;
    stats.lastFetchedAtMs = event.timestampMs;

    notifyListeners();
  }

  /// Clears all accumulated statistics.
  void clear() {
    _stats.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Field to sort [QueryStats] entries by.
enum SortField {
  /// Sort by total fetch count (most active first).
  fetches,

  /// Sort by average fetch duration (slowest first).
  avgDuration,

  /// Sort by error count (most errors first).
  errors,

  /// Sort by last fetch timestamp (most recent first).
  lastActive,
}
