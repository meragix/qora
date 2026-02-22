/// Fonction qui retourne les données de la query
typedef QueryFunction<T> = Future<T> Function();

/// Fonction de mutation
typedef MutationFunction<TData, TVariables> = Future<TData> Function(
  TVariables variables,
);
