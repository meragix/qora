import 'package:qora/src/client/qora_client.dart';
import 'package:qora/src/network/network_mode.dart';
import 'package:qora/src/utils/qora_exception.dart';
import 'package:qora/src/utils/query_function.dart';

import 'infinite_data.dart';
import 'infinite_query_options.dart';
import 'infinite_query_state.dart';

/// Manages the pagination lifecycle for a single infinite query.
///
/// An [InfiniteQueryObserver] handles:
/// - Fetching the initial page via [fetch].
/// - Appending pages via [fetchNextPage].
/// - Prepending pages via [fetchPreviousPage] (bi-directional scroll).
/// - Refetching all loaded pages via [refetch] (e.g. after invalidation).
///
/// Multiple observers sharing the same [key] on the same [client] share
/// the same underlying [InfiniteCacheEntry], so all widgets built from
/// that key receive the same state transitions in sync.
///
/// ## Usage
///
/// Typically created inside a Flutter widget's `State.initState` and
/// disposed in `State.dispose`. For a ready-made Flutter binding see
/// [InfiniteQueryBuilder].
///
/// ```dart
/// final observer = InfiniteQueryObserver<List<Post>, int>(
///   client: client,
///   key: ['posts'],
///   fetcher: (page) => api.getPosts(page: page),
///   options: InfiniteQueryOptions(
///     initialPageParam: 1,
///     getNextPageParam: (last, all) => last.hasMore ? all.length + 1 : null,
///   ),
/// );
///
/// await observer.fetch();
///
/// // Later:
/// await observer.fetchNextPage();
///
/// // Clean up:
/// observer.dispose();
/// ```
class InfiniteQueryObserver<TData, TPageParam> {
  final QoraClient _client;
  final Object _key;
  final InfiniteQueryFunction<TData, TPageParam> _fetcher;
  final InfiniteQueryOptions<TData, TPageParam> _options;

  // ── Concurrency guards ────────────────────────────────────────────────────
  //
  // Each guard is set to `true` as the FIRST synchronous statement in its
  // method — before any `await` — so that rapid double-taps and microtask
  // interleavings are correctly blocked even before the first network
  // round-trip begins.

  bool _isFetchingInitial = false;
  bool _isFetchingNext = false;
  bool _isFetchingPrevious = false;
  bool _isRefetching = false;

  bool _isDisposed = false;

  InfiniteQueryObserver({
    required QoraClient client,
    required Object key,
    required InfiniteQueryFunction<TData, TPageParam> fetcher,
    required InfiniteQueryOptions<TData, TPageParam> options,
  })  : _client = client,
        _key = key,
        _fetcher = fetcher,
        _options = options;

  // ── Public API ────────────────────────────────────────────────────────────

  /// A stream that emits the current [InfiniteQueryState] and every future
  /// transition for this key.
  ///
  /// Backed by the shared [InfiniteCacheEntry] on [client]. Subscribing
  /// prevents the cache entry from being garbage-collected.
  Stream<InfiniteQueryState<TData, TPageParam>> get stream =>
      _client.watchInfiniteState<TData, TPageParam>(_key);

  /// The current [InfiniteQueryState] (synchronous snapshot).
  InfiniteQueryState<TData, TPageParam> get state =>
      _client.getInfiniteQueryState<TData, TPageParam>(_key);

  /// Fetch the first page.
  ///
  /// No-op when:
  /// - Data is already loaded (state is not [InfiniteInitial]).
  /// - An initial fetch is already in progress.
  Future<void> fetch() async {
    if (_isDisposed) return;
    if (_isFetchingInitial) return; // Guard set first — synchronous.
    if (state is! InfiniteInitial<TData, TPageParam>) return;

    _isFetchingInitial = true;

    _client.updateInfiniteQueryState<TData, TPageParam>(
      _key,
      const InfiniteLoading(),
    );

    try {
      final page = await _fetchWithRetry(_options.initialPageParam);
      final data = InfiniteData<TData, TPageParam>(
        pages: List.unmodifiable([page]),
        pageParams: List.unmodifiable([_options.initialPageParam]),
      );
      _emitSuccess(data);
    } catch (e, st) {
      if (_isDisposed) return;
      _client.updateInfiniteQueryState<TData, TPageParam>(
        _key,
        InfiniteFailure(error: e, stackTrace: st),
      );
    } finally {
      _isFetchingInitial = false;
    }
  }

  /// Fetch the next page and append it to the loaded pages.
  ///
  /// No-op when:
  /// - No data has been loaded yet — call [fetch] first.
  /// - [InfiniteSuccess.hasNextPage] is `false`.
  /// - A next-page or previous-page fetch is already in progress.
  Future<void> fetchNextPage() async {
    if (_isDisposed) return;
    if (_isFetchingNext || _isFetchingPrevious) return; // Guard set first.
    _isFetchingNext = true;

    try {
      final currentState = state;
      if (currentState is! InfiniteSuccess<TData, TPageParam>) return;

      final nextParam = _options.getNextPageParam(
        currentState.data.pages.last,
        currentState.data.pages,
      );
      if (nextParam == null) return; // hasNextPage is false.

      // Show per-direction loading indicator; existing pages stay visible.
      _client.updateInfiniteQueryState<TData, TPageParam>(
        _key,
        currentState.copyWith(isFetchingNextPage: true),
      );

      final newPage = await _fetchWithRetry(nextParam);
      var newData = currentState.data.append(newPage, nextParam);

      // Windowed paging: drop the oldest page when over the limit.
      // After dropping, the user can scroll back to the top which triggers
      // fetchPreviousPage() → re-fetches the dropped page via
      // getPreviousPageParam.
      final maxPages = _options.maxPages;
      if (maxPages != null && newData.pages.length > maxPages) {
        newData = newData.dropFirst();
      }

      _emitSuccess(newData);
    } catch (e, st) {
      if (_isDisposed) return;
      final currentState = state;
      _client.updateInfiniteQueryState<TData, TPageParam>(
        _key,
        InfiniteFailure(
          error: e,
          stackTrace: st,
          previousData: currentState is InfiniteSuccess<TData, TPageParam>
              ? currentState.data
              : null,
        ),
      );
    } finally {
      _isFetchingNext = false;
    }
  }

  /// Fetch the previous page and prepend it to the loaded pages.
  ///
  /// Only meaningful when [InfiniteQueryOptions.getPreviousPageParam] is
  /// configured. No-op when [InfiniteSuccess.hasPreviousPage] is `false`
  /// or a fetch is already running.
  Future<void> fetchPreviousPage() async {
    if (_isDisposed) return;
    if (_options.getPreviousPageParam == null) return;
    if (_isFetchingNext || _isFetchingPrevious) return; // Guard set first.
    _isFetchingPrevious = true;

    try {
      final currentState = state;
      if (currentState is! InfiniteSuccess<TData, TPageParam>) return;

      final prevParam = _options.getPreviousPageParam!(
        currentState.data.pages.first,
        currentState.data.pages,
      );
      if (prevParam == null) return; // hasPreviousPage is false.

      _client.updateInfiniteQueryState<TData, TPageParam>(
        _key,
        currentState.copyWith(isFetchingPreviousPage: true),
      );

      final newPage = await _fetchWithRetry(prevParam);
      var newData = currentState.data.prepend(newPage, prevParam);

      // Windowed paging: drop the newest page when over the limit.
      final maxPages = _options.maxPages;
      if (maxPages != null && newData.pages.length > maxPages) {
        newData = newData.dropLast();
      }

      _emitSuccess(newData);
    } catch (e, st) {
      if (_isDisposed) return;
      final currentState = state;
      _client.updateInfiniteQueryState<TData, TPageParam>(
        _key,
        InfiniteFailure(
          error: e,
          stackTrace: st,
          previousData: currentState is InfiniteSuccess<TData, TPageParam>
              ? currentState.data
              : null,
        ),
      );
    } finally {
      _isFetchingPrevious = false;
    }
  }

  /// Refetch all currently loaded pages in sequence.
  ///
  /// Each page is re-fetched using its original [InfiniteData.pageParams],
  /// preserving the current page count. Useful after an
  /// [QoraClient.invalidateInfiniteQuery] call.
  ///
  /// No-op when no data is loaded (delegates to [fetch] instead) or a
  /// refetch is already running.
  Future<void> refetch() async {
    if (_isDisposed) return;
    if (_isRefetching || _isFetchingInitial) return; // Guard set first.
    _isRefetching = true;

    final currentState = state;

    if (currentState is! InfiniteSuccess<TData, TPageParam>) {
      _isRefetching = false;
      // Nothing loaded yet — delegate to initial fetch.
      await fetch();
      return;
    }

    // Snapshot the params before any await so windowed-paging mutations
    // during the refetch do not affect the set of pages being refreshed.
    final originalParams = List<TPageParam>.of(currentState.data.pageParams);

    _client.updateInfiniteQueryState<TData, TPageParam>(
      _key,
      // Reuse isFetchingNextPage as a "globally refreshing" signal.
      currentState.copyWith(isFetchingNextPage: true),
    );

    try {
      final refreshedPages = <TData>[];
      for (final param in originalParams) {
        final page = await _fetchWithRetry(param);
        refreshedPages.add(page);
      }

      final newData = InfiniteData<TData, TPageParam>(
        pages: List.unmodifiable(refreshedPages),
        pageParams: List.unmodifiable(originalParams),
      );
      _emitSuccess(newData);
    } catch (e, st) {
      if (_isDisposed) return;
      final latestState = state;
      _client.updateInfiniteQueryState<TData, TPageParam>(
        _key,
        InfiniteFailure(
          error: e,
          stackTrace: st,
          previousData: latestState is InfiniteSuccess<TData, TPageParam>
              ? latestState.data
              : currentState.data,
        ),
      );
    } finally {
      _isRefetching = false;
    }
  }

  /// Release all resources held by this observer.
  ///
  /// After calling [dispose], all further method calls are silently ignored.
  /// The underlying [InfiniteCacheEntry] on the client is not removed —
  /// other observers sharing the same key continue to operate normally.
  void dispose() {
    _isDisposed = true;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Fetch a single page, with exponential-backoff retry on failure.
  ///
  /// Respects [NetworkMode.online]: throws [QoraOfflineException] immediately
  /// when offline and the effective network mode is [NetworkMode.online].
  Future<TData> _fetchWithRetry(TPageParam pageParam) async {
    final opts = _client.config.defaultOptions.merge(_options.baseOptions);

    if (!_client.isOnline && opts.networkMode == NetworkMode.online) {
      throw const QoraOfflineException();
    }

    var attempt = 0;
    while (true) {
      try {
        return await _fetcher(pageParam);
      } catch (e) {
        if (e is QoraOfflineException) rethrow;
        if (attempt >= opts.retryCount) rethrow;
        await Future<void>.delayed(opts.getRetryDelay(attempt));
        attempt++;
      }
    }
  }

  /// Compute pagination flags and push a new [InfiniteSuccess] state.
  void _emitSuccess(InfiniteData<TData, TPageParam> data) {
    if (_isDisposed) return;

    final hasNextPage = data.isNotEmpty &&
        _options.getNextPageParam(data.pages.last, data.pages) != null;

    final hasPreviousPage = _options.getPreviousPageParam != null &&
        data.isNotEmpty &&
        _options.getPreviousPageParam!(data.pages.first, data.pages) != null;

    _client.updateInfiniteQueryState<TData, TPageParam>(
      _key,
      InfiniteSuccess(
        data: data,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
