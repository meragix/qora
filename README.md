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

| Package | CI | Likes | Downloads | Analysis |
| ------- | -- | ----- | --------- | -------- |
| [![qora](https://img.shields.io/pub/v/qora.svg?label=qora)](https://pub.dev/packages/qora) | [![build](https://github.com/meragix/qora/actions/workflows/dart.yml/badge.svg?branch=main)](https://github.com/meragix/qora/actions/workflows/dart.yml) | [![likes](https://img.shields.io/pub/likes/qora)](https://pub.dev/packages/qora/score) | [![dm](https://img.shields.io/pub/dm/qora)](https://pub.dev/packages/qora/score) | [![pub points](https://img.shields.io/pub/points/qora)](https://pub.dev/packages/qora/score) |
| [![flutter_qora](https://img.shields.io/pub/v/flutter_qora.svg?label=flutter_qora)](https://pub.dev/packages/flutter_qora) | [![build](https://github.com/meragix/qora/actions/workflows/flutter.yml/badge.svg?branch=main)](https://github.com/meragix/qora/actions/workflows/flutter.yml) | [![likes](https://img.shields.io/pub/likes/flutter_qora)](https://pub.dev/packages/flutter_qora/score) | [![dm](https://img.shields.io/pub/dm/flutter_qora)](https://pub.dev/packages/flutter_qora/score) | [![pub points](https://img.shields.io/pub/points/flutter_qora)](https://pub.dev/packages/flutter_qora/score) |
| [![qora_hooks](https://img.shields.io/pub/v/qora_hooks.svg?label=qora_hooks)](https://pub.dev/packages/qora_hooks) | [![build](https://github.com/meragix/qora/actions/workflows/hooks.yml/badge.svg?branch=main)](https://github.com/meragix/qora/actions/workflows/hooks.yml) | [![likes](https://img.shields.io/pub/likes/qora_hooks)](https://pub.dev/packages/qora_hooks/score) | [![dm](https://img.shields.io/pub/dm/qora_hooks)](https://pub.dev/packages/qora_hooks/score) | [![pub points](https://img.shields.io/pub/points/qora_hooks)](https://pub.dev/packages/qora_hooks/score) |
| [![qora_devtools_extension](https://img.shields.io/pub/v/qora_devtools_extension.svg?label=qora_devtools_extension)](https://pub.dev/packages/qora_devtools_extension) | [![build](https://github.com/meragix/qora/actions/workflows/extension.yml/badge.svg?branch=main)](https://github.com/meragix/qora/actions/workflows/extension.yml) | [![likes](https://img.shields.io/pub/likes/qora_devtools_extension)](https://pub.dev/packages/qora_devtools_extension/score) | [![dm](https://img.shields.io/pub/dm/qora_devtools_extension)](https://pub.dev/packages/qora_devtools_extension/score) | [![pub points](https://img.shields.io/pub/points/qora_devtools_extension)](https://pub.dev/packages/qora_devtools_extension/score) |
| [![qora_devtools_overlay](https://img.shields.io/pub/v/qora_devtools_overlay.svg?label=qora_devtools_overlay)](https://pub.dev/packages/qora_devtools_overlay) | [![build](https://github.com/meragix/qora/actions/workflows/overlay.yml/badge.svg?branch=main)](https://github.com/meragix/qora/actions/workflows/overlay.yml) | [![likes](https://img.shields.io/pub/likes/qora_devtools_overlay)](https://pub.dev/packages/qora_devtools_overlay/score) | [![dm](https://img.shields.io/pub/dm/qora_devtools_overlay)](https://pub.dev/packages/qora_devtools_overlay/score) | [![pub points](https://img.shields.io/pub/points/qora_devtools_overlay)](https://pub.dev/packages/qora_devtools_overlay/score) |

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
