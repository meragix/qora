<!-- v0.1.0 - MVP Core         ✅ Pure Dart foundation -->
<!-- v0.2.0 - Flutter Basic    🎨 Basic Flutter widgets -->
<!-- v0.3.0 - Mutations        🔄 Optimistic updates -->
<!-- v0.4.0 - Persistence      💾 Offline-first -->
<!-- v0.5.0 - Network Aware    📡 Connectivity management -->
v0.6.0 - Infinite         ∞  Pagination support
<!-- v0.7.0 - Hooks            🪝 flutter_hooks integration -->
v0.8.0 - DevTools         🛠️ Developer experience
v0.9.0 - Advanced         🚀 Performance & edge cases
v1.0.0 - Production Ready 🎉 Stable release



## v0.7.0 - Infinite Queries ∞

**Objectif** : Support de la pagination infinie

### Packages
```
packages/reqry/          (extension)
packages/reqry_flutter/  (extension)
Features

✅ InfiniteQueryObserver
✅ InfiniteQueryBuilder widget
✅ fetchNextPage() / fetchPreviousPage()
✅ hasNextPage / hasPreviousPage
✅ Page params management
✅ Bi-directional infinite scroll

API
dartInfiniteQueryBuilder<List<Post>, int>(
  queryKey: ReqryKey(['posts']),
  queryFn: (pageParam) => api.getPosts(page: pageParam),
  getNextPageParam: (lastPage, allPages) {
    return lastPage.hasMore ? allPages.length + 1 : null;
  },
  builder: (context, state) {
    final allPosts = state.data?.expand((page) => page).toList() ?? [];
    
    return ListView.builder(
      itemCount: allPosts.length + (state.hasNextPage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == allPosts.length) {
          // Load more trigger
          if (state.hasNextPage && !state.isFetchingNextPage) {
            state.fetchNextPage();
          }
          return CircularProgressIndicator();
        }
        
        return PostCard(allPosts[index]);
      },
    );
  },
)
```

### Examples
- ✅ `examples/infinite_scroll_app/`
- ✅ Twitter-like feed
- ✅ Bi-directional chat

<!-- maintenant on ve son concentrer sur la v0.7.0 dans @roadmap.md ligne 14 pour qora et flutter_qora

tu me propose quel implementation bestpratice et pour scale ?

base in docs/README.md update docs/content with the new feature -->