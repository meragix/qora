import 'qora_options.dart';
import '../utils/qora_exception.dart';

/// Global configuration for [QoraClient].
///
/// Applied to every query as the default baseline. Individual queries can
/// override specific fields by passing [QoraOptions] to [QoraClient.fetchQuery]
/// or [QoraClient.watchQuery].
///
/// ## Example
///
/// ```dart
/// final client = QoraClient(
///   config: QoraClientConfig(
///     defaultOptions: QoraOptions(
///       staleTime: Duration(minutes: 5),
///       cacheTime: Duration(minutes: 10),
///       retryCount: 2,
///     ),
///     debugMode: kDebugMode,
///     maxCacheSize: 200,
///     refetchOnMount: true,
///     errorMapper: (error, stackTrace) => QoraException(
///       error is DioException ? error.message ?? 'Network error' : '$error',
///       originalError: error,
///       stackTrace: stackTrace,
///     ),
///     onCacheEvict: (key) => print('Evicted: $key'),
///   ),
/// );
/// ```
class QoraClientConfig {
  /// Default options applied to every query.
  ///
  /// Per-query [QoraOptions] passed to [QoraClient.fetchQuery] or
  /// [QoraClient.watchQuery] are merged on top of these defaults, with
  /// per-query values taking priority.
  final QoraOptions defaultOptions;

  /// Transforms raw errors into [QoraException] before they are stored in
  /// [Failure] states.
  ///
  /// Use this to normalise API-specific errors (e.g. `DioException`,
  /// `HttpException`) into a consistent shape across your app:
  ///
  /// ```dart
  /// errorMapper: (error, stackTrace) => QoraException(
  ///   error is DioException ? error.message ?? 'Network error' : '$error',
  ///   originalError: error,
  ///   stackTrace: stackTrace,
  /// ),
  /// ```
  ///
  /// When `null` (default), errors are stored as-is.
  final QoraException Function(Object error, StackTrace? stackTrace)?
      errorMapper;

  /// Enables verbose logging to the console.
  ///
  /// Logs cache hits/misses, fetch attempts, retries, deduplication events,
  /// and garbage collection. Recommended value: `kDebugMode` in Flutter apps.
  /// Default: `false`.
  final bool debugMode;

  /// Maximum number of queries held in cache simultaneously.
  ///
  /// When the limit is reached, the least-recently-used *inactive* (no
  /// subscribers) query is evicted to make room. Active queries are never
  /// forcibly evicted. `null` (default) means unbounded.
  final int? maxCacheSize;

  /// Callback invoked whenever a cache entry is evicted — either via LRU,
  /// GC timer, [QoraClient.removeQuery], or [QoraClient.clear].
  ///
  /// Receives the normalised key of the evicted query. Useful for logging,
  /// analytics, or syncing persistent storage.
  final void Function(List<dynamic> key)? onCacheEvict;

  /// Global default for whether [watchQuery] should trigger a fetch on the
  /// first subscription, even when fresh cached data already exists.
  ///
  /// Can be overridden per-query via [QoraOptions.refetchOnMount].
  ///
  /// - `true` (default) — always refetch on mount.
  /// - `false` — only fetch if no data or data is stale.
  final bool refetchOnMount;

  const QoraClientConfig({
    this.defaultOptions = const QoraOptions(),
    this.errorMapper,
    this.debugMode = false,
    this.maxCacheSize,
    this.onCacheEvict,
    this.refetchOnMount = true,
  });
}
