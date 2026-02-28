import 'dart:async';

import '../cache/cached_entry.dart';
import '../cache/query_cache.dart';
import '../config/qora_client_config.dart';
import '../config/qora_options.dart';
import '../key/qora_key.dart';
import '../mutation/mutation_event.dart';
import '../mutation/mutation_state.dart';
import '../mutation/mutation_state_extensions.dart';
import '../mutation/mutation_tracker.dart';
import '../state/qora_state.dart';
import '../tracking/no_op_tracker.dart';
import '../tracking/qora_tracker.dart';

/// The central engine of Qora — manages queries, cache, deduplication,
/// retries, and reactive state.
///
/// ## Initialisation
///
/// ```dart
/// // Minimal (all defaults)
/// final client = QoraClient();
///
/// // With custom configuration
/// final client = QoraClient(
///   config: QoraClientConfig(
///     defaultOptions: QoraOptions(
///       staleTime: Duration(minutes: 5),
///       retryCount: 2,
///     ),
///     debugMode: kDebugMode,
///     maxCacheSize: 200,
///   ),
/// );
/// ```
///
/// ## One-shot fetch
///
/// ```dart
/// final user = await client.fetchQuery<User>(
///   key: ['users', userId],
///   fetcher: () => api.getUser(userId),
/// );
/// ```
///
/// ## Reactive stream
///
/// ```dart
/// client.watchQuery<User>(
///   key: ['users', userId],
///   fetcher: () => api.getUser(userId),
///   options: QoraOptions(refetchInterval: Duration(seconds: 30)),
/// ).listen((state) {
///   switch (state) {
///     case Success(:final data):   updateUI(data);
///     case Failure(:final error):  showError(error);
///     default: {}
///   }
/// });
/// ```
///
/// ## Optimistic update
///
/// ```dart
/// final snapshot = client.getQueryData<User>(['users', userId]);
/// client.setQueryData(['users', userId], optimisticUser);
///
/// try {
///   await api.updateUser(userId, payload);
/// } catch (_) {
///   client.restoreQueryData(['users', userId], snapshot);
/// }
/// ```
class QoraClient implements MutationTracker {
  /// Global configuration for this client instance.
  final QoraClientConfig config;

  /// Observability hook called on query and mutation lifecycle events.
  ///
  /// Defaults to [NoOpTracker] (zero overhead).  Pass a `VmTracker` in
  /// debug/profile builds to enable DevTools reporting.
  final QoraTracker _tracker;

  final QueryCache _cache;

  /// In-flight request futures, keyed by stringified normalised key.
  ///
  /// Enables deduplication: concurrent [fetchQuery] or [watchQuery] calls
  /// with the same key share a single network request.
  final Map<String, Future<dynamic>> _pendingRequests = {};

  // ── Mutation tracking ─────────────────────────────────────────────────────

  /// Snapshot of all **currently pending** mutations, keyed by controller ID.
  ///
  /// Only [MutationPending] entries are kept here. Finished mutations
  /// ([MutationSuccess] / [MutationFailure]) are purged automatically by
  /// [trackMutation] the moment they complete, and idle/disposed controllers
  /// are removed as well.
  ///
  /// Designed for DevTools: read [activeMutations] on connect to see what is
  /// currently running, then subscribe to [mutationEvents] for real-time
  /// updates (including completed events that have already left the snapshot).
  final Map<String, MutationEvent> _activeMutations = {};

  final StreamController<MutationEvent> _mutationBus =
      StreamController<MutationEvent>.broadcast();

  // ─────────────────────────────────────────────────────────────────────────

  Timer? _evictionTimer;
  bool _isDisposed = false;

  /// Creates a [QoraClient].
  ///
  /// [config] — global defaults applied to every query and mutation.
  /// [tracker] — observability hook for DevTools / logging.  Defaults to
  /// [NoOpTracker] (zero overhead).  Inject a `VmTracker` in debug/profile
  /// builds to stream events to Flutter DevTools.
  ///
  /// ```dart
  /// // production
  /// final client = QoraClient();
  ///
  /// // debug — enable DevTools
  /// final client = QoraClient(tracker: VmTracker());
  /// ```
  QoraClient({QoraClientConfig? config, QoraTracker? tracker})
      : config = config ?? const QoraClientConfig(),
        _tracker = tracker ?? const NoOpTracker(),
        _cache = QueryCache(
          maxSize: config?.maxCacheSize,
          onEvict: config?.onCacheEvict,
        ) {
    _startEvictionTimer();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════════════════════════════════

  // ── Fetching ─────────────────────────────────────────────────────────────

  /// Fetch data once and return the result.
  ///
  /// ### Behaviour
  ///
  /// | Cache state        | Action                                      |
  /// |--------------------|---------------------------------------------|
  /// | Fresh (not stale)  | Return cached data immediately (no network) |
  /// | Stale              | Return stale data; revalidate in background  |
  /// | Missing            | Fetch, await, and return result             |
  ///
  /// Concurrent calls with the same key are **deduplicated** — they all
  /// await the same in-flight future. Failed fetches are retried with
  /// exponential backoff up to [QoraOptions.retryCount] times.
  ///
  /// ```dart
  /// final user = await client.fetchQuery<User>(
  ///   key: ['users', userId],
  ///   fetcher: () => api.getUser(userId),
  ///   options: QoraOptions(staleTime: Duration(minutes: 5)),
  /// );
  /// ```
  ///
  /// Throws [StateError] if [QoraOptions.enabled] is `false`.
  /// Throws the fetcher's error (after all retries) on failure.
  Future<T> fetchQuery<T>({
    required Object key,
    required Future<T> Function() fetcher,
    QoraOptions? options,
  }) async {
    _assertNotDisposed();

    final normalized = normalizeKey(key);
    final opts = config.defaultOptions.merge(options);

    if (!opts.enabled) {
      throw StateError('Query is disabled: $normalized');
    }

    final entry = _getOrCreateEntry<T>(normalized);

    // ① Fresh cache hit — return immediately, no network call.
    if (entry.state is Success<T> && !entry.isStale(opts.staleTime)) {
      _log('Cache HIT (fresh): $normalized');
      entry.touch();
      return (entry.state as Success<T>).data;
    }

    // ② Stale-While-Revalidate — return stale data, refetch in background.
    if (entry.state is Success<T>) {
      _log('Cache HIT (stale): $normalized — revalidating in background');
      unawaited(_doFetch<T>(normalized, entry, fetcher, opts));
      return (entry.state as Success<T>).data;
    }

    // ③ Cache miss — fetch and await.
    return _doFetch<T>(normalized, entry, fetcher, opts);
  }

  /// Create a reactive [Stream] of [QoraState] for a query.
  ///
  /// ### Behaviour
  ///
  /// - **Immediate emission**: the current cached state is emitted as soon as
  ///   the stream is subscribed to.
  /// - **Auto-fetch on mount**: triggers a fetch if data is missing or stale
  ///   (controlled by [QoraOptions.refetchOnMount] and
  ///   [QoraClientConfig.refetchOnMount]).
  /// - **Reactive updates**: state changes from *any* source — [fetchQuery],
  ///   [setQueryData], [invalidate] — are pushed to all active streams.
  /// - **Polling**: if [QoraOptions.refetchInterval] is set, the query is
  ///   automatically refetched at that cadence while subscribed.
  /// - **GC on unsubscribe**: when the last subscriber cancels, a GC timer
  ///   is scheduled; the entry is removed after [QoraOptions.cacheTime].
  ///
  /// ```dart
  /// StreamBuilder<QoraState<User>>(
  ///   stream: client.watchQuery<User>(
  ///     key: ['users', userId],
  ///     fetcher: () => api.getUser(userId),
  ///   ),
  ///   builder: (context, snapshot) {
  ///     return switch (snapshot.data) {
  ///       Loading()              => const CircularProgressIndicator(),
  ///       Success(:final data)   => UserWidget(data),
  ///       Failure(:final error)  => ErrorWidget('$error'),
  ///       _                      => const SizedBox.shrink(),
  ///     };
  ///   },
  /// )
  /// ```
  Stream<QoraState<T>> watchQuery<T>({
    required Object key,
    required Future<T> Function() fetcher,
    QoraOptions? options,
  }) async* {
    _assertNotDisposed();

    final normalized = normalizeKey(key);
    final opts = config.defaultOptions.merge(options);
    final entry = _getOrCreateEntry<T>(normalized);

    // Register subscriber — prevents GC while stream is active.
    entry.addSubscriber();
    entry.gcTimer?.cancel();

    try {
      if (opts.enabled) {
        // Decide whether to fetch on mount.
        final shouldRefetchOnMount =
            opts.refetchOnMount ?? config.refetchOnMount;
        final isFirstFetch = entry.state is Initial<T>;
        final isStale = entry.isStale(opts.staleTime);

        if (isFirstFetch || (shouldRefetchOnMount && isStale)) {
          unawaited(_doFetch<T>(normalized, entry, fetcher, opts));
        }

        // Setup polling interval.
        if (opts.refetchInterval != null) {
          entry.refetchTimer?.cancel();
          entry.refetchTimer = Timer.periodic(opts.refetchInterval!, (_) {
            if (!_isDisposed && entry.isActive) {
              unawaited(_doFetch<T>(normalized, entry, fetcher, opts));
            }
          });
        }
      }

      // Yield the current state then forward all future updates.
      yield* entry.stream;
    } finally {
      entry.removeSubscriber();
      entry.refetchTimer?.cancel();
      _scheduleGC(normalized);
    }
  }

  // ── Observe-only stream ───────────────────────────────────────────────────

  /// Subscribe to the [QoraState] stream of a query **without triggering a
  /// fetch**.
  ///
  /// - Immediately emits the current cached state ([Initial] if no entry exists).
  /// - Forwards every subsequent state change pushed by [fetchQuery],
  ///   [setQueryData], [invalidate], etc.
  /// - Suspends the GC timer while at least one subscriber is active, keeping
  ///   the entry alive in cache.
  ///
  /// This is the observe-only counterpart to [watchQuery]. Use it when the
  /// fetch responsibility belongs to another part of your code (e.g.
  /// [QoraStateBuilder] or a parent widget).
  ///
  /// ```dart
  /// client.watchState<User>(['users', userId]).listen((state) {
  ///   switch (state) {
  ///     case Success(:final data): render(data);
  ///     default: {}
  ///   }
  /// });
  /// ```
  Stream<QoraState<T>> watchState<T>(Object key) async* {
    _assertNotDisposed();
    final normalized = normalizeKey(key);
    final entry = _getOrCreateEntry<T>(normalized);
    entry.addSubscriber();
    entry.gcTimer?.cancel();

    try {
      yield* entry.stream;
    } finally {
      entry.removeSubscriber();
      _scheduleGC(normalized);
    }
  }

  // ── Prefetching ──────────────────────────────────────────────────────────

  /// Pre-warm the cache without creating a stream or blocking the caller's UI.
  ///
  /// No-op if the cached data is already fresh. Useful for eager loading
  /// before navigation:
  ///
  /// ```dart
  /// // Prefetch on hover / likely next route
  /// onEnter: (_) => client.prefetch<User>(
  ///   key: ['users', userId],
  ///   fetcher: () => api.getUser(userId),
  /// ),
  /// ```
  Future<void> prefetch<T>({
    required Object key,
    required Future<T> Function() fetcher,
    QoraOptions? options,
  }) async {
    _assertNotDisposed();

    final normalized = normalizeKey(key);
    final opts = config.defaultOptions.merge(options);
    final entry = _getOrCreateEntry<T>(normalized);

    if (entry.state is Success<T> && !entry.isStale(opts.staleTime)) {
      _log('Prefetch skipped (fresh): $normalized');
      return;
    }

    _log('Prefetching: $normalized');
    await _doFetch<T>(normalized, entry, fetcher, opts);
  }

  // ── Cache mutation ───────────────────────────────────────────────────────

  /// Manually set query data in the cache, instantly pushing the new
  /// [Success] state to all active [watchQuery] streams.
  ///
  /// Useful for optimistic updates:
  ///
  /// ```dart
  /// final snapshot = client.getQueryData<User>(['users', userId]);
  ///
  /// // Optimistic update — UI reflects change immediately.
  /// client.setQueryData(['users', userId], updatedUser);
  ///
  /// try {
  ///   await api.updateUser(userId, payload);
  /// } catch (_) {
  ///   // Roll back if server rejects the change.
  ///   client.restoreQueryData(['users', userId], snapshot);
  /// }
  /// ```
  void setQueryData<T>(Object key, T data) {
    _assertNotDisposed();
    final normalized = normalizeKey(key);
    final entry = _getOrCreateEntry<T>(normalized);
    entry.updateState(Success<T>(data: data, updatedAt: DateTime.now()));
    _tracker.onOptimisticUpdate(_stringKey(normalized), data);
    _log('setQueryData: $normalized');
  }

  /// Restore query data from a previous snapshot (optimistic rollback).
  ///
  /// If [snapshot] is `null`, the query is removed from cache entirely.
  ///
  /// ```dart
  /// client.restoreQueryData(['users', userId], snapshot);
  /// ```
  void restoreQueryData<T>(Object key, T? snapshot) {
    _assertNotDisposed();
    if (snapshot == null) {
      removeQuery(key);
    } else {
      setQueryData<T>(key, snapshot);
    }
  }

  // ── Invalidation ─────────────────────────────────────────────────────────

  /// Mark a query as stale and cancel any in-flight request for it.
  ///
  /// Active [watchQuery] streams will transition to
  /// `Loading(previousData: ...)` immediately. The next time a subscriber
  /// mounts or [fetchQuery] is called, a fresh network request will be made.
  ///
  /// ```dart
  /// await api.createPost(payload);
  /// client.invalidate(['posts']);
  /// ```
  void invalidate(Object key) {
    _assertNotDisposed();
    final normalized = normalizeKey(key);
    final entry = _cache.get<dynamic>(normalized);

    if (entry != null) {
      _log('Invalidating: $normalized');
      final previous = entry.state.dataOrNull;
      entry.updateState(
        previous != null
            ? Loading<dynamic>(previousData: previous)
            : Initial<dynamic>(),
      );
      _pendingRequests.remove(_stringKey(normalized));
      _tracker.onQueryInvalidated(_stringKey(normalized));
    }
  }

  /// Invalidate all queries whose normalised keys satisfy [predicate].
  ///
  /// ```dart
  /// // Invalidate every query related to a specific user.
  /// client.invalidateWhere(
  ///   (key) => key.length >= 2 && key[0] == 'users' && key[1] == userId,
  /// );
  ///
  /// // Invalidate all post queries after a mutation.
  /// client.invalidateWhere((key) => key.firstOrNull == 'posts');
  /// ```
  void invalidateWhere(bool Function(List<dynamic> key) predicate) {
    _assertNotDisposed();
    // Collect first to avoid concurrent modification.
    final matched = _cache.findKeys(predicate);
    for (final key in matched) {
      invalidate(key);
    }
  }

  // ── Read ─────────────────────────────────────────────────────────────────

  /// Returns the cached data for [key], or `null` if unavailable.
  ///
  /// Only returns a value when the query is in [Success] state, or in
  /// [Loading]/[Failure] state with [previousData] set.
  ///
  /// ```dart
  /// final user = client.getQueryData<User>(['users', userId]);
  /// ```
  T? getQueryData<T>(Object key) {
    _assertNotDisposed();
    return _cache.get<T>(normalizeKey(key))?.state.dataOrNull;
  }

  /// Returns the full [QoraState] for [key], or [Initial] if not cached.
  ///
  /// ```dart
  /// final state = client.getQueryState<User>(['users', userId]);
  /// if (state is Success<User>) {
  ///   print('Data age: ${state.age}');
  /// }
  /// ```
  QoraState<T> getQueryState<T>(Object key) {
    _assertNotDisposed();
    return _cache.get<T>(normalizeKey(key))?.state ?? Initial<T>();
  }

  // ── Removal ──────────────────────────────────────────────────────────────

  /// Remove a single query from cache and cancel any pending requests for it.
  ///
  /// ```dart
  /// await api.deletePost(postId);
  /// client.removeQuery(['posts', postId]);
  /// ```
  void removeQuery(Object key) {
    _assertNotDisposed();
    final normalized = normalizeKey(key);
    _cache.remove(normalized);
    _pendingRequests.remove(_stringKey(normalized));
    _log('Removed: $normalized');
  }

  /// Remove all cached queries and cancel all pending requests.
  ///
  /// ```dart
  /// // On user logout — clear all cached data.
  /// client.clear();
  /// ```
  void clear() {
    _assertNotDisposed();
    _cache.clear();
    _pendingRequests.clear();
    _tracker.onCacheCleared();
    _log('Cache cleared');
  }

  // ── Mutation observability ────────────────────────────────────────────────

  /// Real-time stream of all mutation state changes from tracked
  /// [MutationController]s.
  ///
  /// Emits a [MutationEvent] on every state transition — including reset to
  /// [MutationIdle]. For the current snapshot on initial connect, read
  /// [activeMutations] first.
  ///
  /// ```dart
  /// client.mutationEvents.listen((event) {
  ///   if (event.isError) showToast('Error: ${event.error}');
  /// });
  /// ```
  Stream<MutationEvent> get mutationEvents => _mutationBus.stream;

  /// Snapshot of all **currently running** (pending) mutations, keyed by
  /// controller ID.
  ///
  /// An entry is added when a [MutationController] transitions to
  /// [MutationPending] and is **automatically purged** as soon as the mutation
  /// finishes ([MutationSuccess] or [MutationFailure]). Controllers that reset
  /// to [MutationIdle] or are disposed are also removed.
  ///
  /// This means [activeMutations] never accumulates "ghost" entries for
  /// completed mutations. For completed events, subscribe to [mutationEvents].
  ///
  /// Use this on DevTools connect to see what is currently in-flight — then
  /// subscribe to [mutationEvents] for real-time state changes.
  ///
  /// ```dart
  /// // On DevTools connect: read pending snapshot, then subscribe to stream.
  /// final pending = client.activeMutations;
  /// client.mutationEvents.listen((event) { ... });
  /// ```
  Map<String, MutationEvent> get activeMutations =>
      Map.unmodifiable(_activeMutations);

  // ── MutationTracker (called by MutationController) ────────────────────────

  @override
  void trackMutation<TData, TVariables>(
    String id,
    MutationState<TData, TVariables> state, {
    Map<String, Object?>? metadata,
  }) {
    if (_isDisposed || _mutationBus.isClosed) return;

    final event = MutationEvent(
      mutatorId: id,
      status: state.status,
      data: state.dataOrNull,
      error: state.errorOrNull,
      variables: state.variablesOrNull,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    // Notify the tracker about mutation lifecycle transitions.
    if (state.isPending) {
      _tracker.onMutationStarted(
        id,
        metadata?['queryKey'] as String? ?? '',
        state.variablesOrNull,
      );
    } else if (state.isSuccess || state.isError) {
      _tracker.onMutationSettled(
        id,
        state.isSuccess,
        state.isSuccess ? state.dataOrNull : state.errorOrNull,
      );
    }

    if (state.isIdle || event.isFinished) {
      // Idle (reset) or finished (success/failure) — purge from snapshot so
      // activeMutations only ever contains currently-running (pending) entries.
      // The event is still emitted on the stream so subscribers see every
      // transition, including completions.
      _activeMutations.remove(id);
    } else {
      // MutationPending — add / update in the snapshot.
      _activeMutations[id] = event;
    }

    _mutationBus.add(event);
    _log('Mutation [$id]: ${state.runtimeType}');
  }

  @override
  void untrackMutation(String id) {
    // Called on dispose — remove silently, no event emitted.
    _activeMutations.remove(id);
  }

  // ── Inspection ───────────────────────────────────────────────────────────

  /// All currently cached query keys (normalised).
  ///
  /// Useful for debugging or implementing custom bulk invalidation:
  ///
  /// ```dart
  /// for (final key in client.cachedKeys) {
  ///   print(key);
  /// }
  /// ```
  Iterable<List<dynamic>> get cachedKeys => _cache.keys;

  /// Returns a debug snapshot of the current cache and mutation state.
  ///
  /// ```dart
  /// print(client.debugInfo());
  /// // {total_queries: 5, active_queries: 2, pending_requests: 1, active_mutations: 1}
  /// ```
  Map<String, dynamic> debugInfo() {
    return {
      ..._cache.debugInfo(),
      'pending_requests': _pendingRequests.length,
      'active_mutations': _activeMutations.length,
    };
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Release all resources held by this client.
  ///
  /// Stops the eviction timer, disposes all cache entries, and cancels all
  /// pending requests. The client **must not** be used after calling [dispose].
  ///
  /// ```dart
  /// // In a DI container teardown or test tearDown:
  /// client.dispose();
  /// ```
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _evictionTimer?.cancel();
    _evictionTimer = null;
    _cache.clear();
    _pendingRequests.clear();
    _activeMutations.clear();
    _mutationBus.close();
    _tracker.dispose();
    _log('QoraClient disposed');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL
  // ══════════════════════════════════════════════════════════════════════════

  /// Core fetch implementation with deduplication and retry.
  ///
  /// Returns the same [Future] to concurrent callers with the same [key]
  /// (deduplication). Updates [entry] with [Loading], [Success], or [Failure]
  /// states as the request progresses.
  Future<T> _doFetch<T>(
    List<dynamic> key,
    CacheEntry<T> entry,
    Future<T> Function() fetcher,
    QoraOptions opts,
  ) {
    final sk = _stringKey(key);

    // Deduplication: reuse the existing in-flight future.
    if (_pendingRequests.containsKey(sk)) {
      _log('Deduplicating: $key');
      return _pendingRequests[sk]! as Future<T>;
    }

    final previousData = entry.state.dataOrNull;
    entry.updateState(Loading<T>(previousData: previousData));

    final future = _executeWithRetry<T>(key: key, fetcher: fetcher, opts: opts)
        .then((data) {
      entry.updateState(Success<T>(data: data, updatedAt: DateTime.now()));
      _tracker.onQueryFetched(_stringKey(key), data, 'success');
      _pendingRequests.remove(sk);
      return data;
    }).catchError((Object error, StackTrace stackTrace) {
      final mapped = _mapError(error, stackTrace);
      entry.updateState(
        Failure<T>(
          error: mapped,
          stackTrace: stackTrace,
          previousData: previousData,
        ),
      );
      _pendingRequests.remove(sk);
      // Re-throw so that await fetchQuery propagates the error to the caller.
      throw mapped; // ignore: only_throw_errors
    });

    _pendingRequests[sk] = future;
    return future;
  }

  /// Execute [fetcher] with up to [QoraOptions.retryCount] retries.
  ///
  /// Each retry is delayed by exponential backoff computed via
  /// [QoraOptions.getRetryDelay].
  Future<T> _executeWithRetry<T>({
    required List<dynamic> key,
    required Future<T> Function() fetcher,
    required QoraOptions opts,
  }) async {
    int attempt = 0;
    Object? lastError;

    while (attempt <= opts.retryCount) {
      try {
        _log('Fetching $key (attempt ${attempt + 1}/${opts.retryCount + 1})');
        return await fetcher();
      } catch (error) {
        lastError = error;
        if (attempt < opts.retryCount) {
          final delay = opts.getRetryDelay(attempt);
          _log(
            'Retry ${attempt + 1}/${opts.retryCount} in ${delay.inMilliseconds} ms',
          );
          await Future<void>.delayed(delay);
        }
        attempt++;
      }
    }

    throw lastError!;
  }

  /// Return an existing [CacheEntry] or create a fresh [Initial] one.
  ///
  /// Performs lazy eviction: if the existing entry has expired, it is
  /// disposed and replaced with a new [Initial] entry.
  CacheEntry<T> _getOrCreateEntry<T>(List<dynamic> key) {
    final existing = _cache.get<T>(key);

    if (existing != null) {
      if (existing.shouldEvict(config.defaultOptions.cacheTime) &&
          !existing.isActive) {
        _log('Lazy evict: $key');
        _cache.remove(key);
      } else {
        return existing;
      }
    }

    _log('Cache MISS: $key');
    final entry = CacheEntry<T>(state: Initial<T>());
    _cache.set(key, entry);
    return entry;
  }

  /// Schedule garbage collection for [key] after [QoraOptions.cacheTime].
  ///
  /// Only removes the entry if it still has no subscribers when the timer
  /// fires. Cancels any previously scheduled GC timer for the same entry.
  void _scheduleGC(List<dynamic> key) {
    final entry = _cache.peek(key);
    if (entry == null || entry.isActive) return;

    entry.gcTimer?.cancel();
    entry.gcTimer = Timer(config.defaultOptions.cacheTime, () {
      if (!entry.isActive) {
        _cache.remove(key);
        _log('GC removed: $key');
      }
    });
  }

  /// Start the background timer that periodically sweeps expired entries.
  void _startEvictionTimer() {
    _evictionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_isDisposed) return;
      _evictExpiredEntries();
    });
  }

  /// Remove all inactive entries that have exceeded their cache time.
  void _evictExpiredEntries() {
    final cacheTime = config.defaultOptions.cacheTime;
    final expired = _cache.entries
        .where((e) => !e.value.isActive && e.value.shouldEvict(cacheTime))
        .map((e) => e.key)
        .toList();

    for (final key in expired) {
      _cache.remove(key);
      _log('Evicted: $key');
    }
  }

  /// Map a raw error through [QoraClientConfig.errorMapper] if configured.
  Object _mapError(Object error, StackTrace stackTrace) {
    if (config.errorMapper != null) {
      return config.errorMapper!(error, stackTrace);
    }
    return error;
  }

  /// Stable string key derived from a normalised key list.
  ///
  /// Used to key [_pendingRequests] (a plain [Map]) without needing deep
  /// equality — list [toString] is deterministic for primitives.
  String _stringKey(List<dynamic> key) => key.toString();

  void _assertNotDisposed() {
    if (_isDisposed) throw StateError('QoraClient has been disposed.');
  }

  void _log(String message) {
    if (config.debugMode) {
      // ignore: avoid_print
      print('[Qora] $message');
    }
  }
}
