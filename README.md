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

| Feature                | Description                                                    |
| ---------------------- | -------------------------------------------------------------- |
| Automatic caching      | Data is stored and served instantly on repeat requests         |
| Stale-while-revalidate | Show cached data immediately, refetch silently in background   |
| Request deduplication  | 10 widgets, same key → 1 network call                          |
| Automatic retry        | Failed requests retry with exponential backoff                 |
| Optimistic updates     | Update the UI before the server responds, roll back on failure |
| Reactive invalidation  | Invalidate a key → every subscriber rebuilds automatically     |

---

## Packages

This monorepo is organized into three domains.

### `packages/dart/` — Pure Dart, no Flutter dependency

| Package | Description |
| ------- | ----------- |
| [`qora`](./packages/dart) | Query client, cache, mutations, optimistic updates. Framework-agnostic — works in Flutter, CLI, or backend. |

### `packages/flutter/` — Flutter widgets and integrations

| Package | Description |
| ------- | ----------- |
| [`qora_flutter`](./packages/flutter) | `QoraBuilder`, `QoraScope`, mutation builders. Depends on `qora`. |

### `packages/devtools/` — Debug tooling, never included in production builds

| Package | Description |
| ------- | ----------- |
| [`qora_devtools_shared`](./packages/devtools/shared) | Shared protocol — events, models, commands and JSON codecs. Pure Dart. |
| [`qora_devtools_extension`](./packages/devtools/extension) | Dart VM Service bridge. Pushes events to the IDE DevTools panel. |
| [`qora_devtools_ui`](./packages/devtools/ui) | Official IDE extension — native tab in VS Code and IntelliJ. |
| [`qora_devtools_overlay`](./packages/devtools/overlay) | In-app overlay panel (debug only). Cache inspector, mutations timeline, optimistic updates, refetch actions. |

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

```yaml
# DevTools overlay — add to dev_dependencies, never ships in production
dev_dependencies:
  qora_devtools_overlay: ^1.0.0
```

Then wrap your app — that's it:

```dart
void main() {
  runApp(
    QoraInspector(        // stripped automatically in release builds
      client: queryClient,
      child: MyApp(),
    ),
  );
}
```

---

## DevTools

Qora ships with first-class developer tooling across two surfaces.

**IDE extension** — a native tab inside Flutter DevTools (VS Code / IntelliJ). Inspect the full cache, replay the event timeline, and send commands (`refetch`, `invalidate`) directly from your IDE. Enabled automatically when `qora_devtools_extension` is in your dependencies.

**In-app overlay** — a draggable panel that lives inside your running app, similar to TanStack Query's overlay. Add `qora_devtools_overlay` to `dev_dependencies` and wrap your app with `QoraInspector`. Zero overhead in release — the widget tree is never built outside of debug mode.

Both surfaces share the same event protocol (`qora_devtools_shared`) and are independent of each other.

---

## Documentation

Full guides, API reference, and examples: **[qora.meragix.dev](https://qora.meragix.dev)**

- [What is Qora?](https://qora.meragix.dev/getting-started/what-is-qora)
- [Quick Start](https://qora.meragix.dev/getting-started/quick-start)
- [Flutter Integration](https://qora.meragix.dev/flutter-integration/setup)
- [Optimistic Updates](https://qora.meragix.dev/guides/optimistic-updates)
- [DevTools](https://qora.meragix.dev/devtools)

---

## Monorepo

This repository is managed with [Melos](https://melos.invertase.dev).

```bash
# Install Melos
dart pub global activate melos

# Bootstrap all packages
melos bootstrap

# Run all tests
melos run test:all

# Analyze all packages
melos run analyze
```

---

Built for the Dart community.
