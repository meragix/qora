import 'package:qora/src/client/qora_client.dart';
import 'package:qora/src/config/qora_client_config.dart';
import 'package:qora/src/managers/connectivity_manager.dart';
import 'package:qora/src/network/network_mode.dart';
import 'package:qora/src/state/qora_state.dart';
import 'package:qora/src/tag/query_tag.dart';
import 'package:qora/src/tracking/qora_tracker.dart';

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
  /// A query is inactive when it has no [QoraClient.watchQuery] subscribers. Once the GC
  /// timer fires, the entry is removed and the next access will trigger a
  /// fresh fetch. Default: 5 minutes.
  ///
  /// Previously named `cacheTime`.
  final Duration gcTime;

  /// Deprecated - use [gcTime] instead.
  @Deprecated('Use gcTime instead')
  Duration get cacheTime => gcTime;

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

  /// Predicate that determines whether a failed fetch should be retried.
  ///
  /// Receives the error and the zero-based attempt index that just failed.
  /// Return `false` to skip further retries for this error.
  ///
  /// When `null` (default), all failures up to [retryCount] are retried.
  ///
  /// ```dart
  /// QoraOptions(
  ///   retryCount: 3,
  ///   retryCondition: (error, attempt) =>
  ///       error is SocketException || attempt == 0,
  /// )
  /// ```
  final bool Function(Object error, int attemptIndex)? retryCondition;

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
  /// [QoraClient.watchQuery] subscriber is active.
  ///
  /// Useful for live/polling data (e.g. prices, notifications, feed).
  /// The timer is cancelled when the last subscriber unsubscribes.
  /// Set to `null` (default) to disable polling.
  ///
  /// ```dart
  /// options: QoraOptions(refetchInterval: Duration(seconds: 30)),
  /// ```
  final Duration? refetchInterval;

  /// Whether to trigger a fetch when a [QoraClient.watchQuery] stream is first
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
  /// resolved; prefer [QoraClient.watchQuery] for reactive dependent queries.
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

  /// Whether to preserve referential equality for unchanged nested data
  /// across fetches.
  ///
  /// When enabled (default), every successful fetch compares the new data
  /// against the existing cache using deep equality. If the data is
  /// structurally unchanged, the previous data reference is kept. This
  /// prevents unnecessary widget rebuilds in deeply nested UIs: widgets
  /// that check `identical(oldData, newData)` or rely on `==` can skip
  /// re-rendering when the data hasn't actually changed.
  ///
  /// The comparison is recursive for [Map], [List], and [Set]. For custom
  /// model classes, `==` and `hashCode` must be overridden for reliable
  /// detection.
  ///
  /// Disable this only if you have very large data structures and the
  /// deep-equality check becomes a measured bottleneck.
  ///
  /// ```dart
  /// // Enabled (default)
  /// QoraOptions(structuralSharing: true),
  ///
  /// // Disabled: always emit new references on every fetch
  /// QoraOptions(structuralSharing: false),
  /// ```
  final bool structuralSharing;

  /// Transform function applied to successful fetch data before it enters the
  /// cache.
  ///
  /// Use this to decouple data transformation from the fetcher: the fetcher
  /// returns raw data (e.g. JSON-decoded maps), and [transform] converts it
  /// into the final model. This makes both the fetcher and the transform
  /// independently testable.
  ///
  /// The transform runs **before** structural sharing, so changes to the
  /// transformed data are correctly detected against the cached entry.
  ///
  /// ```dart
  /// fetchQuery<User>(
  ///   key: ['user', id],
  ///   fetcher: () => api.getUser(id), // raw Map<String, dynamic>
  ///   options: QoraOptions(
  ///     transform: (raw) => User.fromJson(raw as Map<String, dynamic>),
  ///   ),
  /// );
  /// ```
  final Object Function(Object? data)? transform;

  /// Transform function applied to fetch errors before they enter the cache.
  ///
  /// Receives the raw error thrown by the fetcher (after all retries).
  /// Return a different error type to normalise errors across your API layer:
  ///
  /// ```dart
  /// QoraOptions(
  ///   transformError: (error) => switch (error) {
  ///     DioException(e: final err) => AppError.fromDio(err),
  ///     _ => AppError.unknown(error.toString()),
  ///   },
  /// )
  /// ```
  ///
  /// Runs **before** [QoraClientConfig.errorMapper], so the per-query
  /// transform takes precedence for specific queries before the global mapper.
  final Object Function(Object error)? transformError;

  /// Tags that this query provides for tag-based cache invalidation.
  ///
  /// When a mutation invalidates a matching tag (via
  /// [MutationOptions.invalidatesTags]), all queries that provide that tag are
  /// automatically refetched — regardless of their query key.
  ///
  /// This decouples invalidation logic from query-key structure, making it
  /// easier to invalidate related queries across different key patterns:
  ///
  /// ```dart
  /// // A query that provides tags
  /// QoraOptions(
  ///   providesTags: [
  ///     QueryTag('post', postId.toString()),
  ///     QueryTag('author', authorId.toString()),
  ///   ],
  /// )
  /// ```
  final List<QueryTag>? providesTags;

  /// Optional serializer used by DevTools to display query data as structured
  /// JSON.
  ///
  /// When provided, the result of `toJson(data)` is forwarded to the
  /// [QoraTracker] instead of the raw Dart object. This allows the DevTools
  /// overlay and IDE extension to render your models as an interactive JSON
  /// tree rather than falling back to `.toString()`.
  ///
  /// The returned value must be JSON-encodable (`Map`, `List`, `String`,
  /// `num`, `bool`, or `null`).
  ///
  /// ```dart
  /// fetchQuery<User>(
  ///   key: ['user', id],
  ///   fetcher: () => api.getUser(id),
  ///   options: QoraOptions(toJson: (data) => (data as User).toJson()),
  /// );
  /// ```
  ///
  /// If omitted, data that is already a `Map` or `List` (e.g. from
  /// `jsonDecode`) is passed through unchanged. Custom Dart objects fall back
  /// to their `.toString()` representation in the DevTools viewer.
  final Object? Function(Object? data)? toJson;

  const QoraOptions({
    this.staleTime = Duration.zero,
    this.gcTime = const Duration(minutes: 5),
    this.enabled = true,
    this.retryCount = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.retryDelayCalculator,
    this.retryCondition,
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
    this.refetchInterval,
    this.refetchOnMount,
    this.networkMode = NetworkMode.online,
    this.initialData,
    this.initialDataUpdatedAt,
    this.placeholderData,
    this.dependsOn,
    this.structuralSharing = true,
    this.providesTags,
    this.toJson,
    this.transform,
    this.transformError,
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
      gcTime: other.gcTime,
      enabled: other.enabled,
      retryCount: other.retryCount,
      retryDelay: other.retryDelay,
      retryDelayCalculator: other.retryDelayCalculator ?? retryDelayCalculator,
      retryCondition: other.retryCondition ?? retryCondition,
      refetchOnWindowFocus: other.refetchOnWindowFocus,
      refetchOnReconnect: other.refetchOnReconnect,
      refetchInterval: other.refetchInterval ?? refetchInterval,
      refetchOnMount: other.refetchOnMount ?? refetchOnMount,
      networkMode: other.networkMode,
      initialData: other.initialData ?? initialData,
      initialDataUpdatedAt: other.initialDataUpdatedAt ?? initialDataUpdatedAt,
      placeholderData: other.placeholderData ?? placeholderData,
      dependsOn: other.dependsOn ?? dependsOn,
      structuralSharing: other.structuralSharing,
      providesTags: other.providesTags ?? providesTags,
      toJson: other.toJson ?? toJson,
      transform: other.transform ?? transform,
      transformError: other.transformError ?? transformError,
    );
  }
}
