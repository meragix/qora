# Qora

**Async state management for Dart and Flutter — inspired by TanStack Query.**

Stop writing boilerplate to fetch, cache, and sync server data. Qora handles deduplication, stale-while-revalidate, retries, and invalidation so you can focus on your product.

```dart
// Before Qora — 40+ lines of setState, loading flags, error handling, retry logic…

// After Qora — one call, everything handled
final user = await client.fetchQuery<User>(
  key: ['users', userId],
  fetcher: () => api.getUser(userId),
  options: const QoraOptions(staleTime: Duration(minutes: 5)),
);
```

In Flutter, bind it directly to your UI — no `setState`, no `StreamBuilder` boilerplate:

```dart
QoraBuilder<User>(
  queryKey: ['users', userId],
  queryFn: () => api.getUser(userId),
  builder: (context, state) => switch (state) {
    Initial()                          => const SizedBox.shrink(),
    Loading(:final previousData)       => previousData != null
        ? UserCard(previousData)
        : const CircularProgressIndicator(),
    Success(:final data)               => UserCard(data),
    Failure(:final error)              => ErrorScreen(error),
  },
)
```

---

## What you get out of the box

| Feature                 | Description                                                       |
| ----------------------- | ----------------------------------------------------------------- |
| Automatic caching       | Data is stored and served instantly on repeat requests            |
| Stale-while-revalidate  | Show cached data immediately, refetch silently in background      |
| Request deduplication   | 10 widgets, same key → 1 network call                             |
| Automatic retry         | Failed requests retry with exponential backoff                    |
| Optimistic updates      | Update the UI before the server responds, roll back on failure    |
| Reactive invalidation   | Invalidate a key → every subscriber rebuilds automatically        |

---

## Packages

| Package                                   | Description                                           |
| ----------------------------------------- | ----------------------------------------------------- |
| [`qora`](./packages/qora)                 | Pure Dart core — works in Flutter, CLI, or backend    |
| [`flutter_qora`](./packages/flutter_qora) | Flutter widgets: `QoraScope`, `QoraBuilder`, managers |

---

## Install

```yaml
# Flutter app — qora is included automatically
dependencies:
  flutter_qora: ^1.0.0
```

```yaml
# Pure Dart (CLI, backend, shared package)
dependencies:
  qora: ^1.0.0
```

---

## Documentation

Full guides, API reference, and examples: **[qora.meragix.com](https://qora.meragix.com)**

- [What is Qora?](https://qora.meragix.com/getting-started/what-is-qora)
- [Quick Start](https://qora.meragix.com/getting-started/quick-start)
- [Flutter Integration](https://qora.meragix.com/flutter-integration/setup)
- [Optimistic Updates](https://qora.meragix.com/guides/optimistic-updates)

---

Built for the Dart community.
