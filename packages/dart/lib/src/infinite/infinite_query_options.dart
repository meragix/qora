import 'package:qora/src/config/qora_options.dart';

/// Configuration for an infinite (paginated) query.
///
/// Combines standard [QoraOptions] with pagination-specific parameters.
///
/// ```dart
/// InfiniteQueryOptions<List<Post>, int>(
///   initialPageParam: 1,
///   getNextPageParam: (lastPage, allPages) =>
///       lastPage.hasMore ? allPages.length + 1 : null,
///   maxPages: 10,
///   baseOptions: QoraOptions(
///     staleTime: Duration(minutes: 5),
///     retryCount: 2,
///   ),
/// )
/// ```
class InfiniteQueryOptions<TData, TPageParam> {
  /// The page parameter used to fetch the very first page.
  ///
  /// For integer-based pagination: typically `1` or `0`.
  /// For cursor-based pagination: typically an empty string or `null` cast.
  final TPageParam initialPageParam;

  /// Computes the parameter for the **next** page.
  ///
  /// Called with the last fetched page and all fetched pages so far.
  /// Return `null` to signal that there are no more forward pages —
  /// this sets [InfiniteSuccess.hasNextPage] to `false`.
  ///
  /// ```dart
  /// // Integer page numbers
  /// getNextPageParam: (lastPage, allPages) =>
  ///     lastPage.hasMore ? allPages.length + 1 : null,
  ///
  /// // Cursor-based
  /// getNextPageParam: (lastPage, allPages) => lastPage.nextCursor,
  /// ```
  final TPageParam? Function(TData lastPage, List<TData> allPages) getNextPageParam;

  /// Computes the parameter for the **previous** page.
  ///
  /// Only needed for bi-directional infinite scroll (e.g. chat feeds that
  /// start at the latest message and allow scrolling toward older content).
  ///
  /// Return `null` when there are no more previous pages. If not provided,
  /// [InfiniteSuccess.hasPreviousPage] is always `false`.
  ///
  /// ### Windowed paging and page reconstruction
  ///
  /// When [maxPages] is set and pages are dropped from the front of
  /// [InfiniteData.pages], a user scrolling back to the top triggers
  /// [InfiniteQueryObserver.fetchPreviousPage]. This calls `fetcher` with
  /// the param returned here, re-fetching the dropped page. Ensure your
  /// server supports random-access parameters (page numbers or stable
  /// cursors) for correct reconstruction.
  final TPageParam? Function(TData firstPage, List<TData> allPages)? getPreviousPageParam;

  /// Maximum number of pages to keep in memory at once (windowed paging).
  ///
  /// When fetching the next page would exceed this limit, the oldest page
  /// is dropped from the front of [InfiniteData.pages]. When fetching the
  /// previous page would exceed this limit, the newest page is dropped from
  /// the back.
  ///
  /// This prevents unbounded memory growth during long scroll sessions
  /// (Twitter/X-like feeds). Set to `null` (the default) to retain all
  /// pages indefinitely.
  ///
  /// Must be `>= 1` when provided.
  final int? maxPages;

  /// Standard caching, retry, and staleness options applied to every page
  /// fetch performed by this infinite query.
  ///
  /// Merged on top of [QoraClientConfig.defaultOptions].
  final QoraOptions baseOptions;

  const InfiniteQueryOptions({
    required this.initialPageParam,
    required this.getNextPageParam,
    this.getPreviousPageParam,
    this.maxPages,
    this.baseOptions = const QoraOptions(),
  }) : assert(
          maxPages == null || maxPages >= 1,
          'maxPages must be at least 1',
        );
}
