/// Observability interface injected into [QoraClient] to report cache and
/// mutation lifecycle events.
///
/// ## Design rationale — Dependency Inversion
///
/// [QoraClient] calls `_tracker` hooks without knowing whether they go to a
/// DevTools UI, a logging sink, or nowhere at all.  This keeps the core
/// library free of DevTools or platform dependencies:
///
/// ```
/// qora (core) ─── defines QoraTracker interface
///      │
///      ├── NoOpTracker    ← production default, zero overhead
///      └── VmTracker      ← debug/profile, lives in qora_devtools_extension
/// ```
///
/// ## Implementations
///
/// | Class          | Package                  | Purpose                         |
/// |----------------|--------------------------|---------------------------------|
/// | [NoOpTracker]  | `qora`                   | Default — empty no-ops           |
/// | `VmTracker`    | `qora_devtools_extension`| Publishes DevTools events via VM |
///
/// ## Injecting a custom tracker
///
/// ```dart
/// // debug / profile builds only:
/// final client = QoraClient(tracker: VmTracker());
///
/// // or for testing / logging:
/// class LoggingTracker implements QoraTracker {
///   @override
///   void onQueryFetched(String key, Object? data, dynamic status) =>
///       print('[$key] fetched — status: $status');
///   // implement remaining methods …
/// }
/// ```
///
/// ## Thread safety
///
/// All hooks are called **synchronously** on the Flutter/Dart main isolate.
/// Implementations do not need to guard against concurrent access.
abstract interface class QoraTracker {
  /// Whether this tracker requires query data to be serialized before
  /// [onQueryFetched] is called.
  ///
  /// [QoraClient] skips the (potentially expensive) [_serializeForTracker]
  /// call when this returns `false`, which is the case for [NoOpTracker].
  /// DevTools trackers ([VmTracker], [OverlayTracker]) return `true` because
  /// they need a JSON-safe representation of the data for display.
  ///
  /// This flag separates serialization concerns from the core fetch path:
  /// production apps using [NoOpTracker] never pay the serialization cost.
  bool get needsSerialization;
  /// Called when a fetch transitions to the [Loading] state — immediately
  /// before the async fetcher is invoked.
  ///
  /// [key] is the string-serialised normalised key. Pair this event with the
  /// subsequent [onQueryFetched] call to compute fetch duration in
  /// implementations such as `VmTracker`.
  void onQueryFetching(String key);

  /// Called after a query fetch completes successfully and the [Success] state
  /// is committed to the cache.
  ///
  /// [key] is the string-serialised normalised key (e.g. `'["users", 1]'`).
  /// [data] is the raw fetch result (may be large; `VmTracker` applies lazy
  /// chunking when data exceeds 80 KB).
  /// [status] is `'success'` for a normal fetch; implementations may receive
  /// other string values for future SWR sub-states.
  ///
  /// Named parameters carry cache metadata for DevTools display:
  /// - [staleTimeMs] — configured stale threshold in milliseconds (`null` =
  ///   never stale).
  /// - [gcTimeMs] — cache time (GC delay after last subscriber) in
  ///   milliseconds.
  /// - [observerCount] — number of active stream subscribers at the moment
  ///   the fetch settled.
  void onQueryFetched(
    String key,
    Object? data,
    dynamic status, {
    int? staleTimeMs,
    int? gcTimeMs,
    int observerCount = 0,
    int? retryCount,
  });

  /// Called when a fetch was cancelled via [CancelToken] — either before the
  /// request started or while it was in-flight.
  ///
  /// [key] is the string-serialised normalised key. Use this event in DevTools
  /// to mark the query on the timeline as "cancelled" instead of "failed", so
  /// developers understand the request was intentionally aborted.
  void onQueryCancelled(String key);

  /// Called when [QoraClient.invalidate] marks a cache entry as stale.
  ///
  /// [key] is the string-serialised normalised key.
  void onQueryInvalidated(String key);

  /// Called when [QoraClient.removeQuery] evicts a cache entry.
  ///
  /// [key] is the string-serialised normalised key. DevTools implementations
  /// should remove the corresponding row from the query list so the UI
  /// reflects the actual cache state.
  void onQueryRemoved(String key);

  /// Called when [QoraClient.markStale] silently flags a cache entry stale.
  ///
  /// Unlike [onQueryInvalidated], no state transition is pushed to observers
  /// and no refetch is triggered. DevTools implementations should update the
  /// query row to show a stale indicator without showing a loading state.
  void onQueryMarkedStale(String key);

  /// Called when a [MutationController] transitions to [MutationPending].
  ///
  /// [id] is the stable controller identifier (e.g. `'mutation_3'`).
  /// [key] is the associated query key from the mutation's metadata
  /// (`metadata['queryKey']`), or an empty string when not provided.
  /// [variables] are the arguments passed to the mutator (type-erased).
  void onMutationStarted(String id, String key, Object? variables);

  /// Called when a [MutationController] transitions to [MutationSuccess] or
  /// [MutationFailure].
  ///
  /// [success] is `true` for success, `false` for failure.
  /// [result] is the data on success, or the error object on failure.
  void onMutationSettled(String id, bool success, Object? result);

  /// Called when [QoraClient.setQueryData] writes data directly to the cache
  /// (typically an optimistic update before the server confirms).
  ///
  /// [key] is the string-serialised normalised key.
  /// [optimisticData] is the value written to cache.
  void onOptimisticUpdate(String key, Object? optimisticData);

  /// Called when [QoraClient.clear] removes all entries from the cache.
  void onCacheCleared();

  /// Called when the owning [QoraClient] is disposed.
  ///
  /// Implementations should release any resources (buffers, streams, timers)
  /// acquired during tracking.  After [dispose] all other hook methods will
  /// no longer be called.
  void dispose();
}
