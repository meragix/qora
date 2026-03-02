/// Fonction qui retourne les données de la query
typedef QueryFunction<T> = Future<T> Function();

/// Fonction de mutation
typedef MutatorFunction<TData, TVariables> = Future<TData> Function(
  TVariables variables,
);

/// Fonction qui retourne une page de données pour une infinite query.
///
/// Reçoit le paramètre de page ([TPageParam]) et retourne les données
/// correspondantes ([TData]).
///
/// ```dart
/// InfiniteQueryFunction<List<Post>, int> fetchPosts =
///     (page) => api.getPosts(page: page);
/// ```
typedef InfiniteQueryFunction<TData, TPageParam> = Future<TData> Function(
  TPageParam pageParam,
);
