import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_qora/flutter_qora.dart';

import 'use_query_client.dart';

/// Groups all pagination state returned by [useInfiniteQuery].
class InfiniteQueryHandle<TData, TPageParam> {
  /// All pages fetched so far, in order.
  final List<TData> pages;

  /// `true` while the first page is loading.
  final bool isLoading;

  /// `true` while an additional page is being fetched.
  final bool isFetchingNextPage;

  /// `false` when [getNextPageParam] returns `null` for the last page.
  final bool hasNextPage;

  /// The last error that occurred, or `null`.
  final Object? error;

  /// Triggers loading of the next page. No-op if [isFetchingNextPage] is
  /// `true` or [hasNextPage] is `false`.
  final Future<void> Function() fetchNextPage;

  /// `true` when [pages] is empty and no load is in progress.
  bool get isEmpty => pages.isEmpty && !isLoading;

  const InfiniteQueryHandle({
    required this.pages,
    required this.isLoading,
    required this.isFetchingNextPage,
    required this.hasNextPage,
    required this.error,
    required this.fetchNextPage,
  });
}

/// Hook for paginated / infinite-scroll queries.
///
/// Manages page accumulation automatically. Call [InfiniteQueryHandle.fetchNextPage]
/// to load additional pages.
///
/// ```dart
/// class PostsScreen extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final query = useInfiniteQuery<PostsPage, String?>(
///       key: const ['posts'],
///       fetcher: (cursor) => Api.getPosts(cursor: cursor),
///       getNextPageParam: (page) => page.nextCursor,
///       initialPageParam: null,
///     );
///
///     final allPosts = query.pages.expand((p) => p.posts).toList();
///
///     return ListView.builder(
///       itemCount: allPosts.length + (query.hasNextPage ? 1 : 0),
///       itemBuilder: (context, i) {
///         if (i == allPosts.length) {
///           if (!query.isFetchingNextPage) query.fetchNextPage();
///           return const Center(child: CircularProgressIndicator());
///         }
///         return PostTile(allPosts[i]);
///       },
///     );
///   }
/// }
/// ```
InfiniteQueryHandle<TData, TPageParam> useInfiniteQuery<TData, TPageParam>({
  required List<Object?> key,
  required Future<TData> Function(TPageParam pageParam) fetcher,
  required TPageParam? Function(TData lastPage) getNextPageParam,
  required TPageParam initialPageParam,
  QoraOptions? options,
}) {
  final client = useQueryClient();

  final pages = useState<List<TData>>([]);
  final isLoading = useState(false);
  final isFetchingNextPage = useState(false);
  final error = useState<Object?>(null);
  final hasNextPage = useState(true);

  // Load the first page when the key changes.
  useEffect(() {
    // Reset pagination state on key change.
    pages.value = [];
    hasNextPage.value = true;
    error.value = null;

    _fetchPage(
      client: client,
      key: key,
      fetcher: () => fetcher(initialPageParam),
      options: options,
      onStart: () => isLoading.value = true,
      onData: (data) => pages.value = [data],
      onError: (e) => error.value = e,
      onDone: () => isLoading.value = false,
    );
    return null;
  }, [Object.hashAll(key)]);

  Future<void> fetchNextPage() async {
    if (!hasNextPage.value || isFetchingNextPage.value) return;
    if (pages.value.isEmpty) return;

    final nextParam = getNextPageParam(pages.value.last);
    if (nextParam == null) {
      hasNextPage.value = false;
      return;
    }

    isFetchingNextPage.value = true;
    try {
      final newPage = await fetcher(nextParam);
      pages.value = [...pages.value, newPage];
      hasNextPage.value = getNextPageParam(newPage) != null;
    } catch (e) {
      error.value = e;
    } finally {
      isFetchingNextPage.value = false;
    }
  }

  return InfiniteQueryHandle<TData, TPageParam>(
    pages: pages.value,
    isLoading: isLoading.value,
    isFetchingNextPage: isFetchingNextPage.value,
    hasNextPage: hasNextPage.value,
    error: error.value,
    fetchNextPage: fetchNextPage,
  );
}

// ── Internal helpers ─────────────────────────────────────────────────────────

/// Fetches a single page via [QoraClient.fetchQuery] and dispatches results
/// to the provided callbacks.
Future<void> _fetchPage<T>({
  required QoraClient client,
  required Object key,
  required Future<T> Function() fetcher,
  required QoraOptions? options,
  required void Function() onStart,
  required void Function(T data) onData,
  required void Function(Object error) onError,
  required void Function() onDone,
}) async {
  onStart();
  try {
    final data = await client.fetchQuery<T>(
      key: key,
      fetcher: fetcher,
      options: options,
    );
    onData(data);
  } catch (e) {
    onError(e);
  } finally {
    onDone();
  }
}
