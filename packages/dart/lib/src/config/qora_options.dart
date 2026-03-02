import '../network/network_mode.dart';

/// Per-query configuration that overrides global [QoraClientConfig] defaults.
///
/// Pass to [QoraClient.fetchQuery] or [QoraClient.watchQuery] to customise
/// caching, retries, staleness, polling, and network behaviour on a per-query
/// basis.
///
/// All fields have sensible defaults. Override only what you need:
///
/// ```dart
/// client.watchQuery<Price>(
///   key: ['price', symbol],
///   fetcher: () => api.getPrice(symbol),
///   options: QoraOptions(
///     staleTime: Duration(seconds: 10),
///     refetchInterval: Duration(seconds: 5),
///     retryCount: 1,
///     networkMode: NetworkMode.online, // default: pause while offline
///   ),
/// );
/// ```
class QoraOptions {
  /// How long cached data is considered fresh before a background
  /// revalidation is triggered.
  ///
  /// - `Duration.zero` (default) — data is immediately stale; always
  ///   revalidated on the next access.
  /// - `null`-equivalent large value — effectively never stale.
  ///
  /// The SWR (stale-while-revalidate) pattern means stale data is returned
  /// immediately while the fetch runs in the background.
  final Duration staleTime;

  /// How long an *inactive* query is retained in cache before being garbage
  /// collected.
  ///
  /// A query is inactive when it has no [watchQuery] subscribers. Once the GC
  /// timer fires, the entry is removed and the next access will trigger a
  /// fresh fetch. Default: 5 minutes.
  final Duration cacheTime;

  /// Whether this query is allowed to execute.
  ///
  /// When `false`, [QoraClient.fetchQuery] throws immediately and
  /// [QoraClient.watchQuery] emits the current (possibly [Initial]) state
  /// without initiating any network request. Useful for dependent or
  /// conditional queries:
  ///
  /// ```dart
  /// watchQuery(
  ///   key: ['user', userId],
  ///   fetcher: () => api.getUser(userId!),
  ///   options: QoraOptions(enabled: userId != null),
  /// );
  /// ```
  final bool enabled;

  /// Number of automatic retry attempts after a fetch failure.
  ///
  /// Retries use exponential backoff by default (see [retryDelay]).
  /// Set to `0` to disable retries entirely. Default: 3.
  final int retryCount;

  /// Base delay between retry attempts.
  ///
  /// The actual delay grows exponentially per attempt:
  /// - Attempt 0 → `retryDelay × 1` (e.g. 1 s)
  /// - Attempt 1 → `retryDelay × 2` (e.g. 2 s)
  /// - Attempt 2 → `retryDelay × 4` (e.g. 4 s)
  ///
  /// Override with [retryDelayCalculator] for custom backoff strategies.
  final Duration retryDelay;

  /// Custom retry-delay calculator.
  ///
  /// Receives the zero-based attempt index and returns the delay to wait
  /// before that retry. Overrides the default exponential backoff when set.
  ///
  /// Example — constant 500 ms delay:
  /// ```dart
  /// retryDelayCalculator: (_) => const Duration(milliseconds: 500),
  /// ```
  ///
  /// Example — jittered exponential backoff:
  /// ```dart
  /// retryDelayCalculator: (i) =>
  ///   Duration(milliseconds: (500 * pow(2, i) + Random().nextInt(200)).toInt()),
  /// ```
  final Duration Function(int attemptIndex)? retryDelayCalculator;

  /// Whether to refetch this query when the app regains window focus.
  ///
  /// Requires a `LifecycleManager` to be configured on the [QoraClient].
  /// Default: `true`.
  final bool refetchOnWindowFocus;

  /// Whether to refetch this query when the network connection is restored.
  ///
  /// Requires a `ConnectivityManager` to be configured on the [QoraClient].
  /// Default: `true`.
  final bool refetchOnReconnect;

  /// Automatically refetch the query at this interval while at least one
  /// [watchQuery] subscriber is active.
  ///
  /// Useful for live/polling data (e.g. prices, notifications, feed).
  /// The timer is cancelled when the last subscriber unsubscribes.
  /// Set to `null` (default) to disable polling.
  ///
  /// ```dart
  /// options: QoraOptions(refetchInterval: Duration(seconds: 30)),
  /// ```
  final Duration? refetchInterval;

  /// Whether to trigger a fetch when a [watchQuery] stream is first
  /// subscribed to (mounted).
  ///
  /// - `true` — always refetch on mount, even if data is fresh.
  /// - `false` — only fetch if no data or data is stale.
  /// - `null` (default) — falls back to [QoraClientConfig.refetchOnMount].
  final bool? refetchOnMount;

  /// Controls how this query behaves when the device is offline.
  ///
  /// - [NetworkMode.online] (default) — pause while offline, replay on
  ///   reconnect. The query transitions to `Loading(paused)` so the UI can
  ///   show an "Awaiting connection…" indicator.
  /// - [NetworkMode.always] — always execute regardless of network status.
  /// - [NetworkMode.offlineFirst] — serve cache immediately, refetch in the
  ///   background when online.
  ///
  /// Requires a [ConnectivityManager] to be attached to [QoraClient].
  /// If no manager is configured, this option is ignored and fetches always
  /// execute.
  final NetworkMode networkMode;

  /// Static data to pre-populate the cache before the first fetch completes.
  ///
  /// When set, the query immediately starts in [Success] state with this value
  /// instead of [Initial] — eliminating the first loading flash entirely.
  ///
  /// The data is marked with [initialDataUpdatedAt] (default: epoch) so it
  /// is considered immediately stale and a background refetch is triggered on
  /// first mount, replacing it transparently.
  ///
  /// Type note: must match the `<T>` of the query that consumes it. A runtime
  /// type mismatch is silently ignored (the entry stays [Initial]).
  ///
  /// ```dart
  /// fetchQuery<User>(
  ///   key: ['user', id],
  ///   fetcher: () => api.getUser(id),
  ///   options: QoraOptions(initialData: User.empty()),
  /// );
  /// ```
  final Object? initialData;

  /// The timestamp to attach to [initialData] for stale-time calculation.
  ///
  /// Defaults to [DateTime.fromMillisecondsSinceEpoch(0)] (epoch), which
  /// means the initial data is immediately stale and a background refetch
  /// is always triggered on the first mount.
  ///
  /// Set to `DateTime.now()` to treat the initial data as fresh for the
  /// duration of [staleTime]:
  ///
  /// ```dart
  /// QoraOptions(
  ///   initialData: cachedUser,
  ///   initialDataUpdatedAt: prefs.lastFetchedAt,
  ///   staleTime: Duration(minutes: 5),
  /// )
  /// ```
  final DateTime? initialDataUpdatedAt;

  /// Lazy function that returns placeholder data from an already-cached query.
  ///
  /// Called once when the cache entry is first created (state is [Initial]).
  /// If it returns a non-null value of the correct type, the entry transitions
  /// to [Success] immediately — same semantics as [initialData] (epoch
  /// timestamp → always stale → background refetch).
  ///
  /// Prefer [placeholderData] over [initialData] when the value must be
  /// derived from another live cache entry:
  ///
  /// ```dart
  /// QoraOptions(
  ///   placeholderData: () {
  ///     final list = client.getQueryData<List<User>>(['users']);
  ///     return list?.firstWhereOrNull((u) => u.id == userId);
  ///   },
  /// )
  /// ```
  ///
  /// Type note: the returned value must match the `<T>` of the consuming
  /// query. A type mismatch is silently ignored.
  final Object? Function()? placeholderData;

  /// Key of another query that must have [Success] data before this query
  /// fires.
  ///
  /// [QoraClient.watchQuery] subscribes to the dependency reactively: when the
  /// dependency first reaches [Success], the fetch for this query is triggered
  /// automatically — no re-mount required.
  ///
  /// [QoraClient.fetchQuery] throws [StateError] if the dependency is not
  /// resolved; prefer [watchQuery] for reactive dependent queries.
  ///
  /// [QoraClient.prefetch] is a silent no-op when the dependency is not ready.
  ///
  /// ```dart
  /// // Step 1 — fetch the authenticated user's id.
  /// client.watchQuery<Auth>(
  ///   key: ['auth'],
  ///   fetcher: api.getAuth,
  /// );
  ///
  /// // Step 2 — dependent query: fires only after ['auth'] has data.
  /// client.watchQuery<Profile>(
  ///   key: ['profile'],
  ///   fetcher: () {
  ///     final auth = client.getQueryData<Auth>(['auth'])!;
  ///     return api.getProfile(auth.userId);
  ///   },
  ///   options: const QoraOptions(dependsOn: ['auth']),
  /// );
  /// ```
  final Object? dependsOn;

  const QoraOptions({
    this.staleTime = Duration.zero,
    this.cacheTime = const Duration(minutes: 5),
    this.enabled = true,
    this.retryCount = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.retryDelayCalculator,
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
    this.refetchInterval,
    this.refetchOnMount,
    this.networkMode = NetworkMode.online,
    this.initialData,
    this.initialDataUpdatedAt,
    this.placeholderData,
    this.dependsOn,
  });

  /// Returns the retry delay for the given zero-based [attemptIndex].
  ///
  /// Delegates to [retryDelayCalculator] if provided; otherwise applies
  /// exponential backoff: `retryDelay × 2^attemptIndex`.
  Duration getRetryDelay(int attemptIndex) {
    if (retryDelayCalculator != null) {
      return retryDelayCalculator!(attemptIndex);
    }
    return retryDelay * (1 << attemptIndex);
  }

  /// Returns a new [QoraOptions] merging `this` with [other].
  ///
  /// Fields from [other] take priority. Nullable fields in [other]
  /// (e.g. [retryDelayCalculator], [refetchInterval], [refetchOnMount])
  /// fall back to `this` when not set in [other].
  QoraOptions merge(QoraOptions? other) {
    if (other == null) return this;
    return QoraOptions(
      staleTime: other.staleTime,
      cacheTime: other.cacheTime,
      enabled: other.enabled,
      retryCount: other.retryCount,
      retryDelay: other.retryDelay,
      retryDelayCalculator: other.retryDelayCalculator ?? retryDelayCalculator,
      refetchOnWindowFocus: other.refetchOnWindowFocus,
      refetchOnReconnect: other.refetchOnReconnect,
      refetchInterval: other.refetchInterval ?? refetchInterval,
      refetchOnMount: other.refetchOnMount ?? refetchOnMount,
      networkMode: other.networkMode,
      initialData: other.initialData ?? initialData,
      initialDataUpdatedAt: other.initialDataUpdatedAt ?? initialDataUpdatedAt,
      placeholderData: other.placeholderData ?? placeholderData,
      dependsOn: other.dependsOn ?? dependsOn,
    );
  }
}
