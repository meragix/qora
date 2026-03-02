<!-- v0.1.0 - MVP Core         ✅ Pure Dart foundation -->
<!-- v0.2.0 - Flutter Basic    🎨 Basic Flutter widgets -->
<!-- v0.3.0 - Mutations        🔄 Optimistic updates -->
<!-- v0.4.0 - Persistence      💾 Offline-first -->
<!-- v0.5.0 - Network Aware    📡 Connectivity management -->
<!-- v0.6.0 - Infinite         ∞  Pagination support -->
<!-- v0.7.0 - Hooks            🪝 flutter_hooks integration -->
<!-- v0.8.0 - DevTools         🛠️ Developer experience -->
v0.9.0 - Advanced         🚀 Performance & edge cases
v1.0.0 - Production Ready 🎉 Stable release



v0.9.0 - Advanced Features 🚀
Objectif : Optimisations et edge cases

Features
1. Prefetching
dart// Prefetch pour hover states
onHover: () {
  client.prefetchQuery(
    key: ReqryKey(['user', userId]),
    queryFn: () => api.getUser(userId),
  );
}
2. Placeholders
dartQueryBuilder<User>(
  queryKey: ReqryKey(['user', userId]),
  queryFn: () => api.getUser(userId),
  placeholderData: () {
    // Retourner un user depuis la liste des users
    final users = client.getQueryData<List<User>>(ReqryKey(['users']));
    return users?.firstWhere((u) => u.id == userId);
  },
  builder: (context, state) {
    // state.data peut être le placeholder
  },
)
3. Initial Data
dartQueryBuilder<User>(
  queryKey: ReqryKey(['user', userId]),
  queryFn: () => api.getUser(userId),
  initialData: User.empty(),
  builder: (context, state) {
    // Pas de loading state grâce à initialData
  },
)
4. Query Cancellation
dart// Support des CancelToken
final cancelToken = CancelToken();

final data = await client.fetchQuery(
  key: ReqryKey(['search', query]),
  queryFn: () => api.search(query, cancelToken),
  cancelToken: cancelToken,
);

// Plus tard
cancelToken.cancel();
5. Dependent Queries
dart// Query B attend que Query A soit complète
QueryBuilder<User>(
  queryKey: ReqryKey(['user', userId]),
  queryFn: () => api.getUser(userId),
  enabled: userId != null,
  builder: (context, userState) {
    return QueryBuilder<List<Post>>(
      queryKey: ReqryKey(['posts', 'user', userId]),
      queryFn: () => api.getUserPosts(userId),
      enabled: userState.hasData, // ✅ Attend que user soit chargé
      builder: (context, postsState) {
        // ...
      },
    );
  },
)
6. Query Filters
dart// Invalider avec des filtres complexes
client.invalidateQueries(
  filter: (key, query) {
    return key.parts.first == 'posts' && query.data?.isStale == true;
  },
);
7. SSR/Hydration (Web)
dart// Hydrater depuis le serveur
final client = ReqryClient();

client.setQueryData(ReqryKey(['users']), (_) => serverSideUsers);

runApp(ReqryProvider(client: client, child: MyApp()));

<!-- maintenant on ve son concentrer sur la v0.7.0 dans @roadmap.md ligne 14 pour qora et flutter_qora

tu me propose quel implementation bestpratice et pour scale ?

base in docs/README.md update docs/content with the new feature -->