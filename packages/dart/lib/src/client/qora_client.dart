import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:qora/src/cache/cached_entry.dart';
import 'package:qora/src/cache/query_cache.dart';
import 'package:qora/src/cancellation/cancel_token.dart';
import 'package:qora/src/config/qora_client_config.dart';
import 'package:qora/src/config/qora_options.dart';
import 'package:qora/src/infinite/infinite_cache_entry.dart';
import 'package:qora/src/infinite/infinite_data.dart';
import 'package:qora/src/infinite/infinite_query_state.dart';
import 'package:qora/src/key/key_cache_map.dart';
import 'package:qora/src/key/qora_key.dart';
import 'package:qora/src/managers/connectivity_manager.dart';
import 'package:qora/src/managers/lifecycle_manager.dart';
import 'package:qora/src/mutation/mutation.dart';
import 'package:qora/src/network/fetch_status.dart';
import 'package:qora/src/network/network_mode.dart';
import 'package:qora/src/network/offline_mutation_queue.dart';
import 'package:qora/src/state/qora_state.dart';
import 'package:qora/src/tracking/no_op_tracker.dart';
import 'package:qora/src/tracking/qora_tracker.dart';
import 'package:qora/src/utils/qora_exception.dart';

/// The central engine of Qora — manages queries, cache, deduplication,
/// retries, reactive state, and network-aware pausing / reconnect replay.
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
///     reconnectStrategy: ReconnectStrategy(maxConcurrent: 3),
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
///
/// ## Network awareness
///
/// Attach a [ConnectivityManager] (via [QoraScope] or directly) to enable:
/// - Automatic pausing of queries while offline (`NetworkMode.online`)
/// - Batch replay on reconnect with jitter ([ReconnectStrategy])
/// - Offline mutation queue ([OfflineMutationQueue])
///
/// ```dart
/// // Exposed so QoraMutationBuilder can wire the offline queue.
/// final isOnline = client.isOnline;
/// final queue = client.offlineMutationQueue;
/// ```
/// Predicate used by [QoraClient.invalidateQueries] to select cache entries.
///
/// Receives the string-serialised normalised [key], the current [state], and
/// the [lastOptions] recorded from the most recent fetch (or `null` for entries
/// that were pre-populated via `initialData` and never fetched).
///
/// ```dart
/// // Invalidate every query whose key starts with 'users'.
/// client.invalidateQueries(
///   filter: (key, state, opts) => key.startsWith('["users"'),
/// );
///
/// // Invalidate all stale queries that use a refetchInterval.
/// client.invalidateQueries(
///   filter: (key, state, opts) => opts?.refetchInterval != null,
/// );
///
/// // Invalidate only currently-failing queries.
/// client.invalidateQueries(
///   filter: (key, state, opts) => state is Failure,
/// );
/// ```
typedef QueryFilter = bool Function(
  String key,
  QoraState<dynamic> state,
  QoraOptions? lastOptions,
);

/// Internal record holding a deserialized value waiting to be injected into
/// the typed cache via [QoraClient._applyPendingHydration].
///
/// Stored in [QoraClient._pendingHydration] by [QoraClient.queueHydration]
/// and consumed lazily on the first typed API call for that key.
typedef _HydrationEntry = ({dynamic data, DateTime? updatedAt});

class QoraClient implements MutationTracker {
  /// Global configuration for this client instance.
  final QoraClientConfig config;

  /// Observability hook called on query and mutation lifecycle events.
  ///
  /// Defaults to [NoOpTracker] (zero overhead).  Replaced by [setTracker]
  /// in debug/profile builds to enable DevTools reporting.
  QoraTracker _tracker;

  final QueryCache _cache;

  /// In-flight request futures, keyed by stringified normalised key.
  ///
  /// Enables deduplication: concurrent [fetchQuery] or [watchQuery] calls
  /// with the same key share a single network request.
  final Map<String, Future<dynamic>> _pendingRequests = {};

  /// Deserialized values awaiting typed injection into the cache.
  ///
  /// Keyed by JSON-encoded normalised key (same encoding as
  /// [PersistQoraClient._encodeStorageKey] and [SsrHydrator]).
  /// Populated by [queueHydration]; consumed (and removed) lazily by
  /// [_applyPendingHydration] on the first typed API call for that key.
  final Map<String, _HydrationEntry> _pendingHydration = {};

  /// Dedicated cache for infinite (paginated) queries.
  ///
  /// Kept separate from [_cache] so that infinite and regular queries never
  /// collide, even when sharing the same key string.
  final KeyCacheMap<InfiniteCacheEntry<dynamic, dynamic>> _infiniteCache =
      KeyCacheMap<InfiniteCacheEntry<dynamic, dynamic>>();

  // ── Network awareness ──────────────────────────────────────────────────────

  StreamSubscription<NetworkStatus>? _connectivitySubscription;
  NetworkStatus _networkStatus = NetworkStatus.unknown;

  StreamSubscription<LifecycleState>? _lifecycleSubscription;

  /// Replay closures for queries paused while offline.
  ///
  /// Keyed by [_stringKey]. When a query is paused (offline +
  /// [NetworkMode.online]), the closure that would trigger the fetch is stored
  /// here. On reconnect, all closures are replayed in batches per
  /// [ReconnectStrategy].
  final Map<String, Future<void> Function()> _pausedFetches = {};

  /// Per-key broadcast controllers for [FetchStatus] streams.
  ///
  /// Created lazily on first [watchFetchStatus] subscription; removed when
  /// the last subscriber cancels.
  final Map<String, StreamController<FetchStatus>> _fetchStatusBus = {};

  /// Shared queue for offline mutations.
  ///
  /// Accessed by [MutationController] via [offlineMutationQueue] to enqueue
  /// mutations triggered while offline.
  final OfflineMutationQueue _offlineMutationQueue;

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
  final Map<String, MutationUpdate> _activeMutations = {};

  final StreamController<MutationUpdate> _mutationBus =
      StreamController<MutationUpdate>.broadcast();

  /// Broadcast stream that emits the number of in-flight query requests each
  /// time that count changes.  Derive a boolean from `count > 0`.
  final StreamController<int> _fetchingCountBus =
      StreamController<int>.broadcast();

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
        ),
        _offlineMutationQueue = OfflineMutationQueue() {
    _startEvictionTimer();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════════════════════════════════

  // ── Network status ────────────────────────────────────────────────────────

  /// `true` when a [ConnectivityManager] is attached and reports online status,
  /// or when no manager is configured (assumed online by default).
  bool get isOnline =>
      _networkStatus == NetworkStatus.online ||
      _networkStatus == NetworkStatus.unknown;

  /// The current network status as reported by the attached
  /// [ConnectivityManager].
  ///
  /// [NetworkStatus.unknown] when no manager has been attached — queries and
  /// mutations always execute in that case.
  NetworkStatus get networkStatus => _networkStatus;

  /// The shared queue for mutations enqueued while offline.
  ///
  /// Expose to [MutationController] so it can enqueue pending mutations:
  ///
  /// ```dart
  /// MutationController(
  ///   mutator: api.createPost,
  ///   isOnline: () => client.isOnline,
  ///   offlineQueue: client.offlineMutationQueue,
  ///   options: MutationOptions(offlineQueue: true),
  /// )
  /// ```
  OfflineMutationQueue get offlineMutationQueue => _offlineMutationQueue;

  /// Attaches a [ConnectivityManager] and begins listening to network status
  /// changes.
  ///
  /// Called by [QoraScope] after the manager is started. Re-attaching a new
  /// manager is safe — the previous subscription is cancelled first.
  ///
  /// ```dart
  /// // Typically done by QoraScope; only needed for advanced DI setups.
  /// client.attachConnectivityManager(FlutterConnectivityManager());
  /// ```
  void attachConnectivityManager(ConnectivityManager manager) {
    _connectivitySubscription?.cancel();
    _networkStatus = manager.currentStatus;
    _connectivitySubscription = manager.statusStream.listen(
      _onNetworkStatusChanged,
      onError: (Object e) => _log('ConnectivityManager error: $e'),
    );
    _log('ConnectivityManager attached (status: $_networkStatus)');
  }

  /// Attaches a [LifecycleManager] and wires `refetchOnWindowFocus` behaviour.
  ///
  /// When the app resumes ([LifecycleState.resumed]), every active query whose
  /// [QoraOptions.refetchOnWindowFocus] is `true` **and** whose data is stale
  /// is transitioned to `Loading(previousData: ...)`. This causes any mounted
  /// [QoraBuilder] (which listens via [watchState]) to call [fetchQuery] and
  /// trigger a background revalidation — exactly the SWR on-focus pattern.
  ///
  /// Called by [QoraScope] after [LifecycleManager.start]. Re-attaching a new
  /// manager is safe — the previous subscription is cancelled first.
  ///
  /// ```dart
  /// // Done automatically by QoraScope when lifecycleManager is provided.
  /// client.attachLifecycleManager(FlutterLifecycleManager());
  /// ```
  void attachLifecycleManager(LifecycleManager manager) {
    _lifecycleSubscription?.cancel();
    _lifecycleSubscription = manager.lifecycleStream.listen((state) {
      if (state == LifecycleState.resumed) _onAppResumed();
    });
    _log('LifecycleManager attached');
  }

  /// Replaces the active tracker with [tracker].
  ///
  /// Must be called **once**, before any query is issued, and only when the
  /// client was constructed without an explicit tracker (i.e. the default
  /// [NoOpTracker] is still in place).
  ///
  /// Calling this when a non-default tracker is already installed is a
  /// programming error — it asserts in debug mode to surface the mistake early.
  /// Reassigning trackers at runtime leads to lost events (the first tracker
  /// stops receiving hooks silently).
  ///
  /// Prefer the [QoraDevtools.setup] helper from `qora_devtools_extension`,
  /// which calls this method internally:
  ///
  /// ```dart
  /// final client = QoraClient(config: ...);
  /// if (kDebugMode) QoraDevtools.setup(client);
  /// ```
  void setTracker(QoraTracker tracker) {
    assert(
      _tracker is NoOpTracker,
      'QoraClient.setTracker() called when a non-default tracker is already '
      'installed ($_tracker). '
      'Configure the tracker once, before any queries are issued.',
    );
    _tracker = tracker;
  }

  /// Returns a stream of [FetchStatus] changes for [key].
  ///
  /// Emits [FetchStatus.idle] immediately if no fetch is in progress, then
  /// transitions to [FetchStatus.fetching] or [FetchStatus.paused] as needed.
  ///
  /// Used by [QoraBuilder] to provide a third axis of query state alongside
  /// [QoraState], so widgets can distinguish "actively fetching" from "paused
  /// waiting for network" without polling.
  ///
  /// ```dart
  /// client.watchFetchStatus(['users', userId]).listen((fetchStatus) {
  ///   if (fetchStatus == FetchStatus.paused) showOfflineBanner();
  /// });
  /// ```
  Stream<FetchStatus> watchFetchStatus(Object key) {
    final sk = _stringKey(normalizeKey(key));

    StreamSubscription<FetchStatus>? broadcastSub;
    late final StreamController<FetchStatus> localSc;

    localSc = StreamController<FetchStatus>(
      onListen: () {
        localSc.add(_getFetchStatus(sk));

        final bc = _fetchStatusBus.putIfAbsent(
          sk,
          () => StreamController<FetchStatus>.broadcast(),
        );
        broadcastSub = bc.stream.listen(
          localSc.add,
          onError: localSc.addError,
          onDone: localSc.close,
        );
      },
      onCancel: () {
        broadcastSub?.cancel();
        // Clean up the broadcast controller if no other subscribers remain.
        final bc = _fetchStatusBus[sk];
        if (bc != null && !bc.hasListener) {
          _fetchStatusBus.remove(sk);
        }
      },
    );

    return localSc.stream;
  }

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
  /// When offline with [NetworkMode.online]:
  /// - If cached data exists, returns it and schedules a paused fetch for
  ///   replay on reconnect.
  /// - If no cached data, throws [QoraOfflineException].
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
  /// Throws [QoraOfflineException] if offline with no cached data and
  /// [NetworkMode.online].
  /// Throws the fetcher's error (after all retries) on failure.
  Future<T> fetchQuery<T>({
    required Object key,
    required Future<T> Function() fetcher,
    QoraOptions? options,
    CancelToken? cancelToken,
  }) async {
    _assertNotDisposed();

    final normalized = normalizeKey(key);
    final opts = config.defaultOptions.merge(options);

    if (!opts.enabled) {
      throw StateError('Query is disabled: $normalized');
    }

    // dependsOn — throw immediately if the dependency has no data yet.
    // Use watchQuery for reactive dependent queries.
    if (opts.dependsOn != null) {
      final depNorm = normalizeKey(opts.dependsOn!);
      if (_cache.get<dynamic>(depNorm)?.state.dataOrNull == null) {
        throw StateError(
          'fetchQuery: dependency $depNorm is not yet resolved. '
          'Use watchQuery for reactive dependent queries.',
        );
      }
    }

    final entry = _getOrCreateEntry<T>(normalized);

    // Inject any pending hydration data (from PersistQoraClient or SsrHydrator).
    _applyPendingHydration<T>(normalized);

    // Apply initialData / placeholderData to brand-new [Initial] entries.
    _applyInitialData<T>(entry, opts);

    // ① Fresh cache hit — return immediately, no network call.
    if (entry.state is Success<T> && !entry.isStale(opts.staleTime)) {
      _log('Cache HIT (fresh): $normalized');
      entry.touch();
      return (entry.state as Success<T>).data;
    }

    // ② Stale-While-Revalidate — return stale data, refetch in background.
    if (entry.state is Success<T>) {
      // Capture data BEFORE _doFetch — the method synchronously transitions
      // the entry to Loading, so reading entry.state after the call would cast
      // a Loading<T> as Success<T> and throw.
      final staleData = (entry.state as Success<T>).data;
      _log('Cache HIT (stale): $normalized — revalidating in background');
      unawaited(
        _doFetch<T>(
          normalized,
          entry,
          fetcher,
          opts,
          cancelToken: cancelToken,
        ),
      );
      return staleData;
    }

    // ③ Cache miss — fetch and await.
    return _doFetch<T>(
      normalized,
      entry,
      fetcher,
      opts,
      cancelToken: cancelToken,
    );
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
    CancelToken? cancelToken,
  }) async* {
    _assertNotDisposed();

    final normalized = normalizeKey(key);
    final opts = config.defaultOptions.merge(options);
    final entry = _getOrCreateEntry<T>(normalized);

    // Inject any pending hydration data (from PersistQoraClient or SsrHydrator).
    _applyPendingHydration<T>(normalized);

    // Apply initialData / placeholderData before the subscriber is counted
    // so isFirstFetch reflects the pre-populated state correctly.
    _applyInitialData<T>(entry, opts);

    // Register subscriber — prevents GC while stream is active.
    entry.addSubscriber();
    entry.gcTimer?.cancel();

    // Dependency subscription — cancelled in finally.
    StreamSubscription<QoraState<dynamic>>? depSub;

    // Local polling timer — owned exclusively by this watcher instance.
    //
    // Previously this was stored on `entry.refetchTimer` (shared mutable
    // field). When two callers subscribed to the same key concurrently, the
    // second setup cancelled the first caller's timer and replaced it with its
    // own. When the first caller's stream was cancelled, its finally-block then
    // cancelled the second caller's timer — leaving the second caller without
    // polling for the rest of its lifetime.
    //
    // By keeping the timer local, each watcher independently manages its own
    // polling lifecycle. Duplicate fetches are harmless because _doFetch()
    // deduplicates concurrent requests via _pendingRequests.
    Timer? localRefetchTimer;

    try {
      if (opts.enabled) {
        // Decide whether to fetch on mount.
        final shouldRefetchOnMount =
            opts.refetchOnMount ?? config.refetchOnMount;
        final isFirstFetch = entry.state is Initial<T>;
        final isStale = entry.isStale(opts.staleTime);

        if (opts.dependsOn != null) {
          // Reactive dependent query: wait for the dependency to have data.
          final depNorm = normalizeKey(opts.dependsOn!);
          final depEntry = _getOrCreateEntry<dynamic>(depNorm);

          if (depEntry.state.dataOrNull != null) {
            // Dependency already resolved — proceed with normal fetch logic.
            if (isFirstFetch || (shouldRefetchOnMount && isStale)) {
              unawaited(
                _doFetch<T>(
                  normalized,
                  entry,
                  fetcher,
                  opts,
                  cancelToken: cancelToken,
                ),
              );
            }
          } else {
            // Dependency not yet ready — subscribe and fire when it resolves.
            depSub = depEntry.stream.listen((depState) {
              if (depState.dataOrNull != null &&
                  !_isDisposed &&
                  entry.isActive) {
                depSub?.cancel();
                depSub = null;
                unawaited(_doFetch<T>(normalized, entry, fetcher, opts));
              }
            });
          }
        } else {
          if (isFirstFetch || (shouldRefetchOnMount && isStale)) {
            unawaited(
              _doFetch<T>(
                normalized,
                entry,
                fetcher,
                opts,
                cancelToken: cancelToken,
              ),
            );
          }
        }

        // Setup polling interval — stored in a local variable, not on the
        // shared entry, to prevent cross-watcher timer cancellation.
        if (opts.refetchInterval != null) {
          localRefetchTimer = Timer.periodic(opts.refetchInterval!, (_) {
            if (!_isDisposed && entry.isActive) {
              unawaited(_doFetch<T>(normalized, entry, fetcher, opts));
            }
          });
        }
      }

      // Yield the current state then forward all future updates.
      yield* entry.stream;
    } finally {
      depSub?.cancel();
      localRefetchTimer?.cancel();
      entry.removeSubscriber();
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
    _applyPendingHydration<T>(normalized);
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
    CancelToken? cancelToken,
  }) async {
    _assertNotDisposed();

    final normalized = normalizeKey(key);
    final opts = config.defaultOptions.merge(options);

    // dependsOn — silently skip if dependency not resolved (doc contract).
    if (opts.dependsOn != null) {
      final depNorm = normalizeKey(opts.dependsOn!);
      if (_cache.get<dynamic>(depNorm)?.state.dataOrNull == null) {
        _log('Prefetch skipped (dependency not resolved): $normalized');
        return;
      }
    }

    final entry = _getOrCreateEntry<T>(normalized);

    // Inject any pending hydration data (from PersistQoraClient or SsrHydrator).
    _applyPendingHydration<T>(normalized);

    _applyInitialData<T>(entry, opts);

    if (entry.state is Success<T> && !entry.isStale(opts.staleTime)) {
      _log('Prefetch skipped (fresh): $normalized');
      return;
    }

    _log('Prefetching: $normalized');
    await _doFetch<T>(
      normalized,
      entry,
      fetcher,
      opts,
      cancelToken: cancelToken,
    );
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

      // We delegate the invalidation to the entry.
      // The entry 'QueryEntry<T>' already knows its 'T'.
      entry.invalidate();

      _pendingRequests.remove(_stringKey(normalized));
      _emitFetchingCount();
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

  /// Invalidate all queries matching [filter].
  ///
  /// [filter] receives the string key, current state, and the
  /// [QoraOptions] from the last fetch for richer selection than
  /// [invalidateWhere].
  ///
  /// ```dart
  /// // Invalidate every failing query.
  /// client.invalidateQueries(
  ///   filter: (key, state, opts) => state is Failure,
  /// );
  ///
  /// // Invalidate all 'users' queries that have a short staleTime.
  /// client.invalidateQueries(
  ///   filter: (key, state, opts) =>
  ///       key.startsWith('["users"') &&
  ///       (opts?.staleTime ?? Duration.zero) < const Duration(minutes: 1),
  /// );
  /// ```
  void invalidateQueries({required QueryFilter filter}) {
    _assertNotDisposed();
    final matched = _cache.findKeys((key) {
      final entry = _cache.get<dynamic>(key);
      if (entry == null) return false;
      return filter(_stringKey(key), entry.state, entry.lastOptions);
    });
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
    final normalized = normalizeKey(key);
    _applyPendingHydration<T>(normalized);
    return _cache.get<T>(normalized)?.state.dataOrNull;
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
    final normalized = normalizeKey(key);
    _applyPendingHydration<T>(normalized);
    return _cache.get<T>(normalized)?.state ?? Initial<T>();
  }

  // ── Infinite queries ──────────────────────────────────────────────────────

  /// Observe the [InfiniteQueryState] for an infinite query by [key].
  ///
  /// Immediately emits the current state to the subscriber (replay semantics),
  /// then forwards every future [updateInfiniteQueryState] call.
  ///
  /// Subscribing keeps the underlying [InfiniteCacheEntry] alive — the GC
  /// timer is suspended until the last subscriber cancels.
  ///
  /// Used by [InfiniteQueryObserver] and [InfiniteQueryBuilder]; you can also
  /// call it directly when building a custom widget on top of an observer.
  Stream<InfiniteQueryState<TData, TPageParam>>
      watchInfiniteState<TData, TPageParam>(Object key) async* {
    _assertNotDisposed();
    final normalized = normalizeKey(key);
    final entry = _getOrCreateInfiniteEntry<TData, TPageParam>(normalized);

    entry.addSubscriber();
    entry.gcTimer?.cancel();

    try {
      yield* entry.stream;
    } finally {
      entry.removeSubscriber();
      if (!entry.isActive) {
        _scheduleInfiniteGC(normalized, entry);
      }
    }
  }

  /// Push a new [InfiniteQueryState] for [key] to all active subscribers.
  ///
  /// Called by [InfiniteQueryObserver] after every page fetch, success, or
  /// failure. Also useful for optimistic updates:
  ///
  /// ```dart
  /// client.updateInfiniteQueryState<List<Post>, int>(
  ///   ['posts'],
  ///   InfiniteSuccess(
  ///     data: optimisticData,
  ///     hasNextPage: true,
  ///     hasPreviousPage: false,
  ///     updatedAt: DateTime.now(),
  ///   ),
  /// );
  /// ```
  void updateInfiniteQueryState<TData, TPageParam>(
    Object key,
    InfiniteQueryState<TData, TPageParam> state,
  ) {
    _assertNotDisposed();
    final normalized = normalizeKey(key);
    final entry = _getOrCreateInfiniteEntry<TData, TPageParam>(normalized);
    entry.updateState(state);
    _tracker.onQueryFetched(
      _stringKey(normalized),
      state is InfiniteSuccess<TData, TPageParam> ? state.data : null,
      state.runtimeType.toString(),
      observerCount: entry.subscriberCount,
    );
  }

  /// Returns the current [InfiniteQueryState] for [key], or [InfiniteInitial]
  /// if no entry exists yet.
  InfiniteQueryState<TData, TPageParam>
      getInfiniteQueryState<TData, TPageParam>(Object key) {
    _assertNotDisposed();
    final entry = _infiniteCache.get(normalizeKey(key))
        as InfiniteCacheEntry<TData, TPageParam>?;
    return entry?.state ?? const InfiniteInitial();
  }

  /// Returns the loaded [InfiniteData] for [key], or `null` when no pages
  /// have been fetched yet.
  InfiniteData<TData, TPageParam>? getInfiniteQueryData<TData, TPageParam>(
    Object key,
  ) {
    final state = getInfiniteQueryState<TData, TPageParam>(key);
    return switch (state) {
      InfiniteSuccess(:final data) => data,
      InfiniteFailure(:final previousData) => previousData,
      _ => null,
    };
  }

  /// Directly replace the loaded data for an infinite query.
  ///
  /// Preserves [InfiniteSuccess.hasNextPage] and [InfiniteSuccess.hasPreviousPage]
  /// from the current state unless explicit overrides are supplied. Useful for
  /// optimistic updates before a mutation is confirmed.
  void setInfiniteQueryData<TData, TPageParam>(
    Object key,
    InfiniteData<TData, TPageParam> data, {
    bool? hasNextPage,
    bool? hasPreviousPage,
  }) {
    _assertNotDisposed();
    final currentState = getInfiniteQueryState<TData, TPageParam>(key);
    final effectiveHasNext = hasNextPage ??
        (currentState is InfiniteSuccess<TData, TPageParam> &&
            currentState.hasNextPage);
    final effectiveHasPrev = hasPreviousPage ??
        (currentState is InfiniteSuccess<TData, TPageParam> &&
            currentState.hasPreviousPage);

    updateInfiniteQueryState<TData, TPageParam>(
      key,
      InfiniteSuccess(
        data: data,
        hasNextPage: effectiveHasNext,
        hasPreviousPage: effectiveHasPrev,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Reset an infinite query to [InfiniteInitial], signalling observers to
  /// re-fetch from the first page.
  ///
  /// Equivalent to [invalidate] for regular queries — the cache entry is kept
  /// alive (observers receive [InfiniteInitial] and can call `fetch()` again)
  /// rather than being removed entirely.
  void invalidateInfiniteQuery(Object key) {
    _assertNotDisposed();
    final normalized = normalizeKey(key);
    final entry = _infiniteCache.get(normalized);
    if (entry == null) return;
    entry.reset();
    _tracker.onQueryInvalidated(_stringKey(normalized));
    _log('Infinite query invalidated: $normalized');
  }

  // ── Debug / DevTools helpers ─────────────────────────────────────────────

  /// Forces the cached entry for [key] into a [Failure] state with [error].
  ///
  /// Intended exclusively for DevTools "Simulate Error" actions. In release
  /// builds this method still executes, so call it only in debug/profile code
  /// (e.g. behind a `kDebugMode` guard in the overlay).
  ///
  /// No-op when [key] does not exist in the cache.
  void debugSetQueryError(Object key, Object error) {
    _assertNotDisposed();
    final normalized = normalizeKey(key);
    // Use peek (no LRU touch) and setError (T resolved at runtime) so that
    // Failure<T> is correctly typed for the entry's broadcast stream.
    final entry = _cache.peek(normalized);
    if (entry != null) {
      entry.setError(error);
      _tracker.onQueryFetched(_stringKey(normalized), null, 'error');
      _log('debugSetQueryError: $normalized');
    }
  }

  /// Returns `true` when [key] has at least one active [watchQuery] subscriber.
  ///
  /// A query with no active subscriber has no fetcher in scope. DevTools
  /// actions that require a live fetcher (Refetch) should check this before
  /// proceeding and surface a warning when it returns `false`.
  ///
  /// ```dart
  /// if (client.hasActiveWatcher(['users', userId])) {
  ///   client.invalidate(['users', userId]); // will trigger a real network call
  /// }
  /// ```
  bool hasActiveWatcher(Object key) {
    _assertNotDisposed();
    final normalized = normalizeKey(key);
    return _cache.peek(normalized)?.isActive ?? false;
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
    final sk = _stringKey(normalized);
    _cache.remove(normalized);
    _pendingRequests.remove(sk);
    _emitFetchingCount();
    _pausedFetches.remove(sk);
    // Close the broadcast controller for this key so that any active
    // watchFetchStatus() subscriber receives an onDone event instead of
    // silently leaking the StreamController.
    _fetchStatusBus.remove(sk)?.close();
    _tracker.onQueryRemoved(sk);
    _log('Removed: $normalized');
  }

  /// Marks the query for [key] as stale without notifying active observers.
  ///
  /// Unlike [invalidate], this does **not** transition the entry to a
  /// [Loading] state and does **not** trigger an immediate refetch on mounted
  /// [QoraBuilder] widgets.  The stale flag is consumed on the next
  /// [fetchQuery] or [watchQuery] mount — the SWR logic will then trigger a
  /// background revalidation while the UI continues to show the previous data.
  ///
  /// ```dart
  /// // Mark stale silently; the widget refetches on its next mount/interaction.
  /// client.markStale(['users', userId]);
  /// ```
  void markStale(Object key) {
    _assertNotDisposed();
    final normalized = normalizeKey(key);
    final sk = _stringKey(normalized);
    final entry = _cache.peek(normalized);
    if (entry != null) {
      entry.markStale();
      _tracker.onQueryMarkedStale(sk);
      _log('markStale: $normalized');
    }
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
    for (final entry in _infiniteCache.values) {
      entry.dispose();
    }
    _infiniteCache.clear();
    _pendingRequests.clear();
    _emitFetchingCount();
    _pausedFetches.clear();
    _tracker.onCacheCleared();
    _log('Cache cleared');
  }

  // ── Fetch observability ───────────────────────────────────────────────────

  /// The number of query requests currently in flight.
  ///
  /// Useful as an initial value for hooks — read this synchronously, then
  /// subscribe to [fetchingCountStream] for reactive updates.
  ///
  /// ```dart
  /// print(client.isFetchingCount); // 0, 1, 2 …
  /// ```
  int get isFetchingCount => _pendingRequests.length;

  /// Stream that emits the total number of in-flight query requests each time
  /// the count changes.
  ///
  /// Subscribe to this to drive a global loading indicator:
  ///
  /// ```dart
  /// client.fetchingCountStream.map((n) => n > 0).distinct().listen(
  ///   (isFetching) => showGlobalSpinner(isFetching),
  /// );
  /// ```
  Stream<int> get fetchingCountStream => _fetchingCountBus.stream;

  // ── Mutation observability ────────────────────────────────────────────────

  /// Real-time stream of all mutation state changes from tracked
  /// [MutationController]s.
  ///
  /// Emits a [MutationUpdate] on every state transition — including reset to
  /// [MutationIdle]. For the current snapshot on initial connect, read
  /// [activeMutations] first.
  ///
  /// ```dart
  /// client.mutationEvents.listen((event) {
  ///   if (event.isError) showToast('Error: ${event.error}');
  /// });
  /// ```
  Stream<MutationUpdate> get mutationEvents => _mutationBus.stream;

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
  Map<String, MutationUpdate> get activeMutations =>
      Map.unmodifiable(_activeMutations);

  /// A snapshot of all mutations currently waiting in the offline queue.
  ///
  /// Useful for rendering a "pending sync" badge or a list of queued
  /// operations in the UI.
  ///
  /// ```dart
  /// Text('${client.pendingOfflineMutations.length} changes waiting to sync')
  /// ```
  List<dynamic> get pendingOfflineMutations => _offlineMutationQueue.snapshot;

  // ── MutationTracker (called by MutationController) ────────────────────────

  @override
  void trackMutation<TData, TVariables>(
    String id,
    MutationState<TData, TVariables> state, {
    Map<String, Object?>? metadata,
  }) {
    if (_isDisposed || _mutationBus.isClosed) return;

    final isOptimistic =
        state is MutationSuccess<TData, TVariables> && state.isOptimistic;

    final event = MutationUpdate(
      mutatorId: id,
      status: state.status,
      data: state.dataOrNull,
      error: state.errorOrNull,
      variables: state.variablesOrNull,
      timestamp: DateTime.now(),
      metadata: metadata,
      isOptimistic: isOptimistic,
    );

    // Notify the tracker about mutation lifecycle transitions.
    if (state.isPending) {
      final rawKey = metadata?['queryKey'];
      final mutationKey = rawKey == null
          ? ''
          : rawKey is String
              ? rawKey
              : jsonEncode(rawKey);
      _tracker.onMutationStarted(id, mutationKey, state.variablesOrNull);
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
    _log(
      'Mutation [$id]: ${state.runtimeType}${isOptimistic ? ' (optimistic)' : ''}',
    );
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
  /// // {total_queries: 5, active_queries: 2, pending_requests: 1,
  /// //  active_mutations: 1, paused_queries: 3, offline_queue: 2}
  /// ```
  Map<String, dynamic> debugInfo() {
    return {
      ..._cache.debugInfo(),
      'pending_requests': _pendingRequests.length,
      'active_mutations': _activeMutations.length,
      'paused_queries': _pausedFetches.length,
      'offline_queue': _offlineMutationQueue.length,
      'network_status': _networkStatus.name,
    };
  }

  // ── Persistence hooks ────────────────────────────────────────────────────

  /// Extension point for subclasses. Called synchronously after every
  /// successful fetch inside [_doFetch] — covering both direct fetches and
  /// SWR background revalidations.
  ///
  /// The default implementation is a no-op. Override in [PersistQoraClient]
  /// (or any subclass) to react to fresh data without duplicating the full
  /// [fetchQuery] / [watchQuery] logic.
  ///
  /// Fire-and-forget async work inside the override using [unawaited] so that
  /// the fetch caller is never blocked by storage I/O.
  @visibleForOverriding
  void onFetchSuccess<T>(List<dynamic> key, T data) {}

  /// Pre-populate the cache with a previously persisted value.
  ///
  /// Inserts a [Success] state for [key] with [data] and the given [updatedAt]
  /// timestamp. Typically called by [PersistQoraClient.hydrate] at startup to
  /// restore persisted data before the first network request.
  ///
  /// Behaviour:
  /// - **No-op** when the entry already has a non-[Initial] state — avoids
  ///   overwriting a live in-flight fetch (race condition on slow storage).
  /// - Passing the original `persistedAt` as [updatedAt] lets
  ///   [QoraOptions.staleTime] determine freshness correctly: if the data is
  ///   older than `staleTime`, the first [watchQuery] mount will trigger a
  ///   SWR background revalidation automatically.
  ///
  /// ```dart
  /// // Restore a previously fetched user from disk:
  /// client.hydrateQuery<User>(
  ///   ['users', userId],
  ///   persistedUser,
  ///   updatedAt: persistedAt,
  /// );
  /// ```
  void hydrateQuery<T>(Object key, T data, {DateTime? updatedAt}) {
    _assertNotDisposed();
    final normalized = normalizeKey(key);
    final entry = _getOrCreateEntry<T>(normalized);
    if (entry.state is Initial<T>) {
      entry.updateState(
        Success<T>(data: data, updatedAt: updatedAt ?? DateTime.now()),
      );
      _log('Hydrated: $normalized');
    }
  }

  /// Enqueue a pre-deserialized value to be injected into the typed cache on
  /// the first typed API call ([fetchQuery], [watchQuery], etc.) for [key].
  ///
  /// This is the shared hydration mechanism used by [PersistQoraClient] and
  /// [SsrHydrator]. Prefer those higher-level APIs unless you are building a
  /// custom hydration source.
  ///
  /// The actual injection is deferred to avoid Dart's sound type-system cast
  /// failure: a [CacheEntry<dynamic>] cannot be cast to [CacheEntry<T>] at
  /// runtime unless the entry was originally created as [CacheEntry<T>].
  /// By calling [_applyPendingHydration<T>] at the first typed call site, the
  /// entry is created with the correct [T] from the start.
  ///
  /// [data] must be the already-deserialized Dart object (not raw JSON).
  /// [updatedAt] is used for stale-time calculation — defaults to epoch (always
  /// stale, triggers SWR revalidation on first mount).
  void queueHydration(
    Object key,
    dynamic data, {
    DateTime? updatedAt,
  }) {
    final normalized = normalizeKey(key);
    final pk = _encodePendingKey(normalized);
    _pendingHydration[pk] = (data: data, updatedAt: updatedAt);
    _log('Hydration queued: $normalized');
  }

  /// Remove the pending hydration entry for [key] without injecting it.
  ///
  /// Called by [PersistQoraClient.removeQuery] and [PersistQoraClient.clear]
  /// to keep the pending queue consistent with the in-memory cache.
  @protected
  void removeHydrationEntry(Object key) {
    final normalized = normalizeKey(key);
    _pendingHydration.remove(_encodePendingKey(normalized));
  }

  /// Remove all pending hydration entries.
  ///
  /// Called by [PersistQoraClient.clear] when the entire cache is wiped.
  @protected
  void clearHydrationQueue() => _pendingHydration.clear();

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
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _lifecycleSubscription?.cancel();
    _lifecycleSubscription = null;
    _cache.clear();
    for (final entry in _infiniteCache.values) {
      entry.dispose();
    }
    _infiniteCache.clear();
    _pendingRequests.clear();
    _pendingHydration.clear();
    _pausedFetches.clear();
    _activeMutations.clear();
    _offlineMutationQueue.clear();
    for (final bc in _fetchStatusBus.values) {
      bc.close();
    }
    _fetchStatusBus.clear();
    _mutationBus.close();
    _fetchingCountBus.close();
    _tracker.dispose();
    _log('QoraClient disposed');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL
  // ══════════════════════════════════════════════════════════════════════════

  // ── Network callbacks ─────────────────────────────────────────────────────

  void _onAppResumed() {
    _log('App resumed — checking stale queries for refetchOnWindowFocus');
    for (final mapEntry in _cache.entries) {
      final entry = mapEntry.value;
      final opts = entry.lastOptions;
      // Only act on queries that are currently observed, have been fetched at
      // least once (lastOptions != null), opted into focus-refetch, and are
      // stale according to their configured staleTime.
      if (!entry.isActive) continue;
      if (opts?.refetchOnWindowFocus != true) continue;
      if (!entry.isStale(opts?.staleTime)) continue;
      // Transitioning to Loading(previousData: ...) is the signal that
      // QoraBuilder._subscribe() watches for: it calls _executeFetch() which
      // invokes fetchQuery with the watcher's fetcher closure, completing the
      // SWR on-focus revalidation cycle.
      entry.invalidate();
      _log('refetchOnWindowFocus: invalidated ${mapEntry.key}');
    }
  }

  void _onNetworkStatusChanged(NetworkStatus status) {
    final wasOffline = _networkStatus == NetworkStatus.offline;
    _networkStatus = status;
    _log('Network status changed: $status');

    if (wasOffline && status == NetworkStatus.online) {
      unawaited(_onReconnect());
    }
  }

  Future<void> _onReconnect() async {
    _log('Reconnected — replaying ${_pausedFetches.length} paused queries '
        'and ${_offlineMutationQueue.length} queued mutations');

    // Replay queries in batches to avoid the thundering herd.
    await _replayPausedFetches();

    // Replay offline mutation queue after queries so that server data is fresh.
    if (!_offlineMutationQueue.isEmpty) {
      final result = await _offlineMutationQueue.replay();
      _log('Offline mutation replay: ${result.succeeded} ok, '
          '${result.failed} failed, ${result.skipped.length} skipped');
    }
  }

  Future<void> _replayPausedFetches() async {
    if (_pausedFetches.isEmpty) return;

    final strategy = config.reconnectStrategy;
    final keys = _pausedFetches.keys.toList();
    final replays = _pausedFetches.values.toList();
    _pausedFetches.clear();

    final random = Random();
    for (var i = 0; i < keys.length; i += strategy.maxConcurrent) {
      final batch = replays.sublist(
        i,
        (i + strategy.maxConcurrent).clamp(0, replays.length),
      );

      await Future.wait(batch.map((fn) => fn()));

      // Jitter between batches to spread the server load spike.
      if (strategy.jitter > Duration.zero &&
          i + strategy.maxConcurrent < keys.length) {
        final jitterMs = random.nextInt(strategy.jitter.inMilliseconds + 1);
        await Future<void>.delayed(Duration(milliseconds: jitterMs));
      }
    }
  }

  // ── Pending hydration ─────────────────────────────────────────────────────

  /// Consume the pending hydration entry for [key] (if any) and inject it
  /// into the cache as a correctly-typed [CacheEntry<T>].
  ///
  /// Must be called before [super] in every method that creates or reads a
  /// cache entry, so that the hydrated state is visible on the very first
  /// access.
  void _applyPendingHydration<T>(List<dynamic> normalized) {
    final pk = _encodePendingKey(normalized);
    final pending = _pendingHydration.remove(pk);
    if (pending == null) return;

    try {
      hydrateQuery<T>(
        normalized,
        pending.data as T,
        updatedAt: pending.updatedAt,
      );
    } catch (e) {
      _log('Hydration cast failed at "$pk": $e');
    }
  }

  /// Encodes a normalised key to a stable JSON string used as the pending-
  /// hydration map key (mirrors [PersistQoraClient._encodeStorageKey]).
  String _encodePendingKey(List<dynamic> key) => jsonEncode(key);

  // ── FetchStatus helpers ───────────────────────────────────────────────────

  FetchStatus _getFetchStatus(String sk) {
    if (_pendingRequests.containsKey(sk)) return FetchStatus.fetching;
    if (_pausedFetches.containsKey(sk)) return FetchStatus.paused;
    return FetchStatus.idle;
  }

  void _emitFetchStatus(String sk, FetchStatus status) {
    _fetchStatusBus[sk]?.add(status);
  }

  void _emitFetchingCount() {
    if (!_fetchingCountBus.isClosed) {
      _fetchingCountBus.add(_pendingRequests.length);
    }
  }

  // ── Core fetch ────────────────────────────────────────────────────────────

  /// Core fetch implementation with deduplication, network-mode awareness,
  /// and retry.
  ///
  /// Returns the same [Future] to concurrent callers with the same [key]
  /// (deduplication). Updates [entry] with [Loading], [Success], or [Failure]
  /// states as the request progresses.
  Future<T> _doFetch<T>(
    List<dynamic> key,
    CacheEntry<T> entry,
    Future<T> Function() fetcher,
    QoraOptions opts, {
    CancelToken? cancelToken,
  }) {
    final sk = _stringKey(key);

    // Pre-flight cancellation check — before dedup and offline checks.
    if (cancelToken?.isCancelled == true) {
      _tracker.onQueryCancelled(sk);
      return Future.error(QoraCancelException(sk));
    }

    // Deduplication: reuse the existing in-flight future.
    if (_pendingRequests.containsKey(sk)) {
      _log('Deduplicating: $key');
      return _pendingRequests[sk]! as Future<T>;
    }

    // Dedup against already-paused fetches.
    if (_pausedFetches.containsKey(sk)) {
      _log('Already paused (offline): $key');
      final cached = entry.state.dataOrNull;
      if (cached != null) return Future.value(cached as T);
      return Future.error(
        const QoraOfflineException(
          'Query paused: device is offline and no cached data is available.',
        ),
      );
    }

    // ── Offline handling ────────────────────────────────────────────────────

    final isCurrentlyOffline = _networkStatus == NetworkStatus.offline;

    if (isCurrentlyOffline && opts.networkMode == NetworkMode.online) {
      return _pauseFetch<T>(sk, key, entry, fetcher, opts);
    }

    if (isCurrentlyOffline && opts.networkMode == NetworkMode.offlineFirst) {
      final cached = entry.state.dataOrNull;
      if (cached != null) {
        // Serve cache now; queue a background refetch for when online.
        _pausedFetches[sk] = () async {
          await _doFetch<T>(key, entry, fetcher, opts);
        };
        _emitFetchStatus(sk, FetchStatus.paused);
        _log('offlineFirst — serving cache, queuing refetch: $key');
        return Future.value(cached as T);
      }
      // No cache → fall through to normal pause.
      return _pauseFetch<T>(sk, key, entry, fetcher, opts);
    }

    // ── Normal online fetch ─────────────────────────────────────────────────

    final previousState = entry.state;
    final previousData = entry.state.dataOrNull;
    entry.updateState(Loading<T>(previousData: previousData));
    _emitFetchStatus(sk, FetchStatus.fetching);
    _tracker.onQueryFetching(sk);

    final future =
        _executeWithRetry<T>(key: key, fetcher: fetcher, opts: opts).then(
      (result) {
        final data = result.value;
        // Mid-flight cancellation — discard result, restore pre-fetch state.
        if (cancelToken?.isCancelled == true) {
          entry.updateState(previousState);
          _pendingRequests.remove(sk);
          _emitFetchingCount();
          _emitFetchStatus(sk, FetchStatus.idle);
          _tracker.onQueryCancelled(sk);
          throw QoraCancelException(sk); // ignore: only_throw_errors
        }

        entry.lastOptions = opts;
        entry.updateState(Success<T>(data: data, updatedAt: DateTime.now()));
        _tracker.onQueryFetched(
          _stringKey(key),
          // Serialization is skipped for NoOpTracker (production default) so
          // the JSON walk never runs in release builds. DevTools trackers
          // declare needsSerialization = true and receive the full payload.
          _tracker.needsSerialization ? _serializeForTracker(data, opts) : null,
          'success',
          staleTimeMs: opts.staleTime.inMilliseconds,
          gcTimeMs: opts.cacheTime.inMilliseconds,
          observerCount: entry.subscriberCount,
          retryCount: result.attempts,
          // Propagate the declarative dependency key so DevTools trackers can
          // build real Query→Query edges without temporal heuristics.
          dependsOnKey: opts.dependsOn != null
              ? _stringKey(normalizeKey(opts.dependsOn!))
              : null,
        );
        onFetchSuccess<T>(key, data);
        _pendingRequests.remove(sk);
        _emitFetchingCount();
        _emitFetchStatus(sk, FetchStatus.idle);
        return data;
      },
    ).catchError((Object error, StackTrace stackTrace) {
      // If the token was cancelled and the underlying HTTP client threw its own
      // cancellation error, normalise it into QoraCancelException.
      if (cancelToken?.isCancelled == true && error is! QoraCancelException) {
        entry.updateState(previousState);
        _pendingRequests.remove(sk);
        _emitFetchingCount();
        _emitFetchStatus(sk, FetchStatus.idle);
        _tracker.onQueryCancelled(sk);
        throw QoraCancelException(sk); // ignore: only_throw_errors
      }
      // QoraCancelException thrown from the .then() callback — re-throw as-is.
      if (error is QoraCancelException) {
        throw error; // ignore: only_throw_errors
      }
      final mapped = _mapError(error, stackTrace);
      entry.updateState(
        Failure<T>(
          error: mapped,
          stackTrace: stackTrace,
          previousData: previousData,
        ),
      );
      _pendingRequests.remove(sk);
      _emitFetchingCount();
      _emitFetchStatus(sk, FetchStatus.idle);
      // Re-throw so that await fetchQuery propagates the error to the caller.
      throw mapped; // ignore: only_throw_errors
    });

    _pendingRequests[sk] = future;
    _emitFetchingCount();
    return future;
  }

  /// Pause a fetch because the device is offline.
  ///
  /// - Transitions the entry to `Loading(previousData: ...)` so the UI
  ///   knows a fetch is pending.
  /// - Emits [FetchStatus.paused].
  /// - Stores a replay closure in [_pausedFetches].
  /// - Returns the stale cached data if available, or throws
  ///   [QoraOfflineException] if not.
  Future<T> _pauseFetch<T>(
    String sk,
    List<dynamic> key,
    CacheEntry<T> entry,
    Future<T> Function() fetcher,
    QoraOptions opts,
  ) {
    // Transition to Loading so the UI reflects that a fetch is pending.
    final previousData = entry.state.dataOrNull;
    if (entry.state is! Loading<T>) {
      entry.updateState(Loading<T>(previousData: previousData));
    }

    // Register for replay on reconnect.
    _pausedFetches[sk] = () async {
      await _doFetch<T>(key, entry, fetcher, opts);
    };

    _emitFetchStatus(sk, FetchStatus.paused);
    _log('Paused (offline): $key');

    if (previousData != null) {
      return Future.value(previousData as T);
    }

    return Future.error(
      const QoraOfflineException(
        'Query paused: device is offline and no cached data is available.',
      ),
    );
  }

  /// Execute [fetcher] with up to [QoraOptions.retryCount] retries.
  ///
  /// Each retry is delayed by exponential backoff computed via
  /// [QoraOptions.getRetryDelay].
  Future<({T value, int attempts})> _executeWithRetry<T>({
    required List<dynamic> key,
    required Future<T> Function() fetcher,
    required QoraOptions opts,
  }) async {
    int attempt = 0;
    Object? lastError;

    while (attempt <= opts.retryCount) {
      try {
        _log('Fetching $key (attempt ${attempt + 1}/${opts.retryCount + 1})');
        final value = await fetcher();
        return (value: value, attempts: attempt);
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

  /// If [entry] is still in [Initial] state and [opts] supplies
  /// [QoraOptions.initialData] or [QoraOptions.placeholderData], pre-populate
  /// the entry with a [Success] state so callers never see an [Initial] flash.
  ///
  /// The [Success] timestamp defaults to the Unix epoch, making the data
  /// immediately stale → a background refetch is always triggered on mount,
  /// keeping the placeholder ephemeral.
  ///
  /// A runtime type mismatch between the provided value and `<T>` is silently
  /// ignored — the entry remains [Initial] and fetches normally.
  void _applyInitialData<T>(CacheEntry<T> entry, QoraOptions opts) {
    if (entry.state is! Initial<T>) return;

    final raw = opts.initialData ?? opts.placeholderData?.call();
    if (raw == null || raw is! T) return;

    entry.updateState(
      Success<T>(
        data: raw as T, // safe: guarded by `raw is! T` check above
        updatedAt:
            opts.initialDataUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    _log('initialData applied: ${entry.state}');
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

  /// Return an existing [InfiniteCacheEntry] or create a fresh [InfiniteInitial] one.
  InfiniteCacheEntry<TData, TPageParam>
      _getOrCreateInfiniteEntry<TData, TPageParam>(List<dynamic> key) {
    final existing =
        _infiniteCache.get(key) as InfiniteCacheEntry<TData, TPageParam>?;
    if (existing != null) {
      existing.touch();
      return existing;
    }
    final entry = InfiniteCacheEntry<TData, TPageParam>(
      state: const InfiniteInitial(),
    );
    _infiniteCache.set(key, entry);
    return entry;
  }

  /// Schedule garbage collection for an [InfiniteCacheEntry] after
  /// [QoraOptions.cacheTime].
  void _scheduleInfiniteGC(
    List<dynamic> key,
    InfiniteCacheEntry<dynamic, dynamic> entry,
  ) {
    entry.gcTimer?.cancel();
    entry.gcTimer = Timer(config.defaultOptions.cacheTime, () {
      if (!entry.isActive) {
        _infiniteCache.remove(key);
        _log('GC removed infinite: $key');
      }
    });
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

  /// Start the background eviction cycle.
  ///
  /// Schedules a one-shot [Timer] that fires exactly when the
  /// earliest-expiring inactive entry is due, then reschedules itself after
  /// each tick. Falls back to a 1-minute heartbeat when no inactive entries
  /// exist, acting as a safety net for orphaned entries.
  ///
  /// Benefits over `Timer.periodic(1 minute)`:
  /// - Zero allocation in the common case (nothing to evict).
  /// - Entries are collected as promptly as their `cacheTime` allows.
  /// - The event loop is not loaded at a fixed cadence regardless of need.
  void _startEvictionTimer() {
    _scheduleNextEviction();
  }

  /// Compute the delay to the earliest pending expiry and arm a one-shot timer.
  void _scheduleNextEviction() {
    if (_isDisposed) return;

    final cacheTime = config.defaultOptions.cacheTime;
    DateTime? earliest;

    for (final entry in _cache.entries) {
      final e = entry.value;
      if (e.isActive) continue;
      final expiry = e.lastAccessedAt.add(cacheTime);
      if (earliest == null || expiry.isBefore(earliest)) {
        earliest = expiry;
      }
    }

    Duration delay;
    if (earliest == null) {
      // No inactive entries — safety-net heartbeat.
      delay = const Duration(minutes: 1);
    } else {
      final d = earliest.difference(DateTime.now());
      delay = d.isNegative ? Duration.zero : d;
    }

    _evictionTimer = Timer(delay, _evictionTick);
  }

  void _evictionTick() {
    if (_isDisposed) return;
    _evictExpiredEntries();
    _scheduleNextEviction();
  }

  /// Remove all inactive entries that have exceeded their cache time.
  ///
  /// Zero-allocation fast path: the removal list is only allocated when at
  /// least one expired entry is found.
  void _evictExpiredEntries() {
    final cacheTime = config.defaultOptions.cacheTime;
    List<List<dynamic>>? toRemove;

    for (final entry in _cache.entries) {
      final e = entry.value;
      if (!e.isActive && e.shouldEvict(cacheTime)) {
        (toRemove ??= []).add(entry.key);
      }
    }

    if (toRemove != null) {
      for (final key in toRemove) {
        _cache.remove(key);
        _log('Evicted: $key');
      }
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
  String _stringKey(List<dynamic> key) => jsonEncode(key);

  void _assertNotDisposed() {
    if (_isDisposed) throw StateError('QoraClient has been disposed.');
  }

  /// Converts [data] into a JSON-safe value for the DevTools tracker.
  ///
  /// Resolution order:
  /// 1. [opts.toJson] — explicit serializer, always wins.
  /// 2. Recursively walks `List` and `Map` — serializes each element.
  /// 3. Dynamic `toJson()` call — works for `json_serializable`/`freezed` models.
  /// 4. Structured fallback — never throws; always returns a diagnostic map.
  ///
  /// Only called when [QoraTracker.needsSerialization] is `true`.
  Object? _serializeForTracker(Object? data, QoraOptions opts) {
    if (opts.toJson != null) return opts.toJson!(data);
    return _toJsonSafe(data);
  }

  Object? _toJsonSafe(Object? data) {
    if (data == null || data is String || data is num || data is bool) {
      return data;
    }
    if (data is List) {
      return data.map(_toJsonSafe).toList();
    }
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), _toJsonSafe(v)));
    }

    // Attempt dynamic dispatch to toJson() — the standard contract for
    // json_serializable / freezed / built_value generated models.
    try {
      final result = (data as dynamic).toJson();
      // Validate the return type: toJson() must produce a Map or List.
      // If it returns a primitive (e.g. a mis-implemented toJson that returns
      // toString()), wrap it in a diagnostic envelope so DevTools shows
      // something meaningful rather than silently dropping the data.
      if (result is Map || result is List) return result;
      return {
        '__type': data.runtimeType.toString(),
        '__value': result?.toString() ?? 'null',
        '__warning':
            'toJson() returned ${result.runtimeType} instead of Map/List',
      };
    } catch (e) {
      if (e is NoSuchMethodError) {
        // Model has no toJson() — structured fallback, not a crash.
        return {
          '__type': data.runtimeType.toString(),
          '__value': data.toString(),
          '__hint':
              'Add toJson() or pass QoraOptions(toJson: (d) => d.toJson())',
        };
      }
      // toJson() exists but threw — surface the error in DevTools instead of
      // silently discarding it. This makes serialization failures visible and
      // actionable without crashing the app.
      _log('_toJsonSafe: toJson() threw for ${data.runtimeType}: $e');
      return {
        '__type': data.runtimeType.toString(),
        '__serializationError': e.toString(),
      };
    }
  }

  void _log(String message) {
    if (config.debugMode) {
      // ignore: avoid_print
      print('[Qora] $message');
    }
  }
}
