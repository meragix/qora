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
  /// Called after a query fetch completes successfully and the [Success] state
  /// is committed to the cache.
  ///
  /// [key] is the string-serialised normalised key (e.g. `'["users", 1]'`).
  /// [data] is the raw fetch result (may be large; `VmTracker` applies lazy
  /// chunking when data exceeds 80 KB).
  /// [status] is `'success'` for a normal fetch; implementations may receive
  /// other string values for future SWR sub-states.
  void onQueryFetched(String key, Object? data, dynamic status);

  /// Called when [QoraClient.invalidate] marks a cache entry as stale.
  ///
  /// [key] is the string-serialised normalised key.
  void onQueryInvalidated(String key);

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
