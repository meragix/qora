import 'package:qora/src/tracking/qora_tracker.dart';

/// A [QoraTracker] that fans out every hook call to a list of child trackers.
///
/// Use [MultiTracker] when you need two DevTools surfaces active at the same
/// time, for example the IDE extension ([VmTracker]) and the in-app overlay
/// ([OverlayTracker]):
///
/// ```dart
/// final overlay = OverlayTracker();
/// final client  = QoraClient();
///
/// if (kDebugMode) {
///   QoraDevtools.setup(client, additionalTrackers: [overlay]);
/// }
///
/// runApp(QoraInspector(tracker: overlay, child: MyApp(client: client)));
/// ```
///
/// ## needsSerialization
///
/// Returns `true` as soon as **any** child tracker requires serialization.
/// This keeps the core fetch path cheap when all trackers are [NoOpTracker],
/// while enabling the JSON step the moment a single DevTools tracker is live.
///
/// ## Ordering
///
/// Hooks are dispatched in list order. If a tracker throws, subsequent
/// trackers in the list will not be called for that event. In practice, all
/// built-in trackers are exception-safe, so ordering only matters for
/// deterministic testing.
///
/// ## Dispose
///
/// [dispose] is forwarded to **every** child. After disposal, the child list
/// is cleared to release references.
final class MultiTracker implements QoraTracker {
  /// Creates a tracker that dispatches to all [trackers].
  ///
  /// [trackers] must not be empty; pass at least two trackers (otherwise
  /// a single tracker or [NoOpTracker] is more appropriate).
  MultiTracker(List<QoraTracker> trackers)
      : _trackers = List<QoraTracker>.unmodifiable(trackers);

  List<QoraTracker> _trackers;

  /// `true` when at least one child tracker requires data serialization.
  ///
  /// [QoraClient] skips the (potentially expensive) JSON serialization step
  /// when this returns `false`. [MultiTracker] propagates the most demanding
  /// requirement so that no tracker is starved of data it needs.
  @override
  bool get needsSerialization => _trackers.any((t) => t.needsSerialization);

  @override
  void onQueryFetching(String key) {
    for (final t in _trackers) {
      t.onQueryFetching(key);
    }
  }

  @override
  void onQueryFetched(
    String key,
    Object? data,
    dynamic status, {
    int? staleTimeMs,
    int? gcTimeMs,
    int observerCount = 0,
    int? retryCount,
    String? dependsOnKey,
  }) {
    for (final t in _trackers) {
      t.onQueryFetched(
        key,
        data,
        status,
        staleTimeMs: staleTimeMs,
        gcTimeMs: gcTimeMs,
        observerCount: observerCount,
        retryCount: retryCount,
        dependsOnKey: dependsOnKey,
      );
    }
  }

  @override
  void onQueryCancelled(String key) {
    for (final t in _trackers) {
      t.onQueryCancelled(key);
    }
  }

  @override
  void onQueryInvalidated(String key) {
    for (final t in _trackers) {
      t.onQueryInvalidated(key);
    }
  }

  @override
  void onQueryRemoved(String key) {
    for (final t in _trackers) {
      t.onQueryRemoved(key);
    }
  }

  @override
  void onQueryMarkedStale(String key) {
    for (final t in _trackers) {
      t.onQueryMarkedStale(key);
    }
  }

  @override
  void onMutationStarted(String id, String key, Object? variables) {
    for (final t in _trackers) {
      t.onMutationStarted(id, key, variables);
    }
  }

  @override
  void onMutationSettled(String id, bool success, Object? result) {
    for (final t in _trackers) {
      t.onMutationSettled(id, success, result);
    }
  }

  @override
  void onOptimisticUpdate(String key, Object? optimisticData) {
    for (final t in _trackers) {
      t.onOptimisticUpdate(key, optimisticData);
    }
  }

  @override
  void onCacheCleared() {
    for (final t in _trackers) {
      t.onCacheCleared();
    }
  }

  @override
  void dispose() {
    for (final t in _trackers) {
      t.dispose();
    }
    _trackers = const [];
  }
}
