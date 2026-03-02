import 'package:meta/meta.dart';

/// Immutable container holding all fetched pages and their corresponding
/// page parameters for an infinite query.
///
/// [TData] is the type of a single page (e.g. `List<Post>`).
/// [TPageParam] is the type of the page parameter (e.g. `int`, `String`,
/// or a cursor value).
///
/// Both [pages] and [pageParams] are always the same length:
/// `pages[i]` was fetched using `pageParams[i]`.
@immutable
class InfiniteData<TData, TPageParam> {
  /// All fetched pages in order — first page at index 0.
  final List<TData> pages;

  /// The page parameters used to fetch each page.
  ///
  /// `pageParams[i]` is the parameter that was passed to `queryFn` to
  /// produce `pages[i]`. Storing the params alongside the pages makes it
  /// possible to refetch each page individually during [InfiniteQueryObserver.refetch].
  final List<TPageParam> pageParams;

  const InfiniteData({
    required this.pages,
    required this.pageParams,
  }) : assert(
          // ignore: prefer_is_empty
          pages.length == pageParams.length,
          'pages and pageParams must have the same length',
        );

  /// Total number of pages currently loaded.
  int get pageCount => pages.length;

  /// Whether no pages have been loaded yet.
  bool get isEmpty => pages.isEmpty;

  /// Whether at least one page has been loaded.
  bool get isNotEmpty => pages.isNotEmpty;

  /// Flatten all pages into a single list using [selector].
  ///
  /// This is the canonical way to convert a `List<Page>` into the flat
  /// item list required by `ListView.builder`:
  ///
  /// ```dart
  /// // When TData == List<Post>
  /// final posts = data.flatten((page) => page);
  ///
  /// // When TData is a response object with a nested list
  /// final posts = data.flatten((page) => page.items);
  /// ```
  List<TItem> flatten<TItem>(Iterable<TItem> Function(TData page) selector) =>
      pages.expand<TItem>(selector).toList(growable: false);

  /// Creates a new [InfiniteData] with [page] and [param] appended at the end.
  ///
  /// Used internally by [InfiniteQueryObserver.fetchNextPage].
  InfiniteData<TData, TPageParam> append(TData page, TPageParam param) =>
      InfiniteData(
        pages: List.unmodifiable([...pages, page]),
        pageParams: List.unmodifiable([...pageParams, param]),
      );

  /// Creates a new [InfiniteData] with [page] and [param] prepended at the front.
  ///
  /// Used internally by [InfiniteQueryObserver.fetchPreviousPage] for
  /// bi-directional infinite scroll (e.g. chat feed loading older messages).
  InfiniteData<TData, TPageParam> prepend(TData page, TPageParam param) =>
      InfiniteData(
        pages: List.unmodifiable([page, ...pages]),
        pageParams: List.unmodifiable([param, ...pageParams]),
      );

  /// Creates a new [InfiniteData] without its first page (windowed paging).
  ///
  /// Called when [InfiniteQueryOptions.maxPages] is set and appending a
  /// new next-page would exceed the limit. After dropping, the user can
  /// scroll back to the top to trigger [InfiniteQueryObserver.fetchPreviousPage],
  /// which re-fetches the dropped page using [getPreviousPageParam].
  InfiniteData<TData, TPageParam> dropFirst() {
    assert(pages.isNotEmpty, 'Cannot drop from empty InfiniteData');
    return InfiniteData(
      pages: List.unmodifiable(pages.skip(1)),
      pageParams: List.unmodifiable(pageParams.skip(1)),
    );
  }

  /// Creates a new [InfiniteData] without its last page (windowed paging).
  ///
  /// Called when [InfiniteQueryOptions.maxPages] is set and prepending a
  /// new previous-page would exceed the limit.
  InfiniteData<TData, TPageParam> dropLast() {
    assert(pages.isNotEmpty, 'Cannot drop from empty InfiniteData');
    return InfiniteData(
      pages: List.unmodifiable(pages.take(pages.length - 1)),
      pageParams: List.unmodifiable(pageParams.take(pageParams.length - 1)),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InfiniteData<TData, TPageParam> &&
        _listEquals(other.pages, pages) &&
        _listEquals(other.pageParams, pageParams);
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(pages), Object.hashAll(pageParams));

  @override
  String toString() =>
      'InfiniteData(pageCount: $pageCount, params: $pageParams)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
