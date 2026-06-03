/// Function that returns query data.
typedef QueryFunction<T> = Future<T> Function();

/// Mutation function.
typedef MutatorFunction<TData, TVariables> = Future<TData> Function(
  TVariables variables,
);

/// Function that returns one page of data for an infinite query.
///
/// Receives the page parameter ([TPageParam]) and returns the corresponding
/// data ([TData]).
///
/// ```dart
/// InfiniteQueryFunction<List<Post>, int> fetchPosts =
///     (page) => api.getPosts(page: page);
/// ```
typedef InfiniteQueryFunction<TData, TPageParam> = Future<TData> Function(
  TPageParam pageParam,
);
