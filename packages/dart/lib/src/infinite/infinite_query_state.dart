import 'infinite_data.dart';

/// The state machine for an infinite (paginated) query.
///
/// Mirrors the structure of [QoraState] but extends it with
/// pagination-specific fields:
///
/// - [InfiniteSuccess] carries [InfiniteSuccess.isFetchingNextPage] and
///   [InfiniteSuccess.isFetchingPreviousPage] so the UI can display
///   per-direction loading indicators while keeping existing pages visible.
/// - [InfiniteFailure] carries [InfiniteFailure.previousData] so the UI can
///   show stale content alongside an error banner instead of a blank screen.
///
/// ## Pattern matching
///
/// ```dart
/// switch (state) {
///   case InfiniteInitial() || InfiniteLoading():
///     return const CircularProgressIndicator();
///   case InfiniteSuccess(:final data, :final hasNextPage, :final isFetchingNextPage):
///     return PostFeed(
///       items: data.flatten((page) => page),
///       hasMore: hasNextPage,
///       loadingMore: isFetchingNextPage,
///     );
///   case InfiniteFailure(:final error, :final previousData):
///     if (previousData != null) {
///       return Column(children: [
///         PostFeed(items: previousData.flatten((p) => p)),
///         ErrorBanner(error),
///       ]);
///     }
///     return ErrorScreen(error);
/// }
/// ```
sealed class InfiniteQueryState<TData, TPageParam> {
  const InfiniteQueryState();
}

/// The query has not been executed yet.
final class InfiniteInitial<TData, TPageParam>
    extends InfiniteQueryState<TData, TPageParam> {
  const InfiniteInitial();
}

/// The initial page fetch is in progress (no pages loaded yet).
///
/// For subsequent page fetches while data is already available, see
/// [InfiniteSuccess.isFetchingNextPage] and
/// [InfiniteSuccess.isFetchingPreviousPage] — those transitions do not
/// reset to [InfiniteLoading]; existing pages remain visible.
final class InfiniteLoading<TData, TPageParam>
    extends InfiniteQueryState<TData, TPageParam> {
  const InfiniteLoading();
}

/// All currently loaded pages, with pagination status flags.
///
/// When [isFetchingNextPage] or [isFetchingPreviousPage] is `true`, [data]
/// still holds all previously loaded pages — the UI must never go blank.
final class InfiniteSuccess<TData, TPageParam>
    extends InfiniteQueryState<TData, TPageParam> {
  /// All loaded pages and their corresponding page parameters.
  final InfiniteData<TData, TPageParam> data;

  /// Whether a next-page fetch is currently in progress.
  ///
  /// When `true`, render a loading indicator at the bottom of the list
  /// while keeping [data] visible.
  final bool isFetchingNextPage;

  /// Whether a previous-page fetch is currently in progress.
  ///
  /// When `true`, render a loading indicator at the top of the list
  /// while keeping [data] visible.
  final bool isFetchingPreviousPage;

  /// Whether more pages are available in the forward direction.
  ///
  /// Derived from [InfiniteQueryOptions.getNextPageParam] returning non-null
  /// for the last loaded page.
  final bool hasNextPage;

  /// Whether more pages are available in the backward direction.
  ///
  /// Derived from [InfiniteQueryOptions.getPreviousPageParam] returning
  /// non-null for the first loaded page. Always `false` when no
  /// [getPreviousPageParam] is configured.
  final bool hasPreviousPage;

  /// When this state was last successfully updated.
  final DateTime updatedAt;

  const InfiniteSuccess({
    required this.data,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.updatedAt,
    this.isFetchingNextPage = false,
    this.isFetchingPreviousPage = false,
  });

  /// Returns a copy with the given fields overridden.
  InfiniteSuccess<TData, TPageParam> copyWith({
    InfiniteData<TData, TPageParam>? data,
    bool? isFetchingNextPage,
    bool? isFetchingPreviousPage,
    bool? hasNextPage,
    bool? hasPreviousPage,
    DateTime? updatedAt,
  }) =>
      InfiniteSuccess(
        data: data ?? this.data,
        isFetchingNextPage: isFetchingNextPage ?? this.isFetchingNextPage,
        isFetchingPreviousPage:
            isFetchingPreviousPage ?? this.isFetchingPreviousPage,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// A fetch failure, with optional [previousData] for graceful degradation.
///
/// When [previousData] is non-null, the UI should show existing content
/// alongside an error indicator rather than replacing the entire view.
final class InfiniteFailure<TData, TPageParam>
    extends InfiniteQueryState<TData, TPageParam> {
  /// The error thrown by the fetch function (after all retries).
  final Object error;

  /// Optional stack trace from the fetch failure.
  final StackTrace? stackTrace;

  /// The last successfully loaded pages, if any.
  ///
  /// Non-null when a failure occurs during a page fetch while data is
  /// already available (e.g. a next-page fetch fails after several pages
  /// have already been loaded).
  final InfiniteData<TData, TPageParam>? previousData;

  const InfiniteFailure({
    required this.error,
    this.stackTrace,
    this.previousData,
  });
}
