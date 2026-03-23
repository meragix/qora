<br />
<div align="center">
  <a href="https://github.com/meragix/qora">
    <img src="assets/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">Qora</h3>

  <p align="center">Server-state management engine for Dart and Flutter.</a>.
    <br />
    <a href="https://qora.meragix.dev"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/meragix/qora/blob/main/CONTRIBUTING.md">Contribute</a>
    &middot;
    <a href="https://github.com/meragix/qora/issues/new">Report Bug</a>
    &middot;
    <a href="https://github.com/meragix/qora/issues/new">Request Feature</a>
  </p>
</div>
<br />

Qora handles query deduplication, stale-while-revalidate caching, automatic retry with backoff, and cache invalidation. One API covers both pure Dart and Flutter targets.

```dart
final user = await client.fetchQuery<User>(
  key: ['users', userId],
  fetcher: () => api.getUser(userId),
  options: const QoraOptions(staleTime: Duration(minutes: 5)),
);
```

In Flutter, bind it directly to the widget tree:

```dart
QoraBuilder<User>(
  queryKey: ['users', userId],
  fetcher: () => api.getUser(userId),
  builder: (context, state, fetchStatus) => switch (state) {
    Initial() => const SizedBox.shrink(),
    Loading(:final previousData) => previousData != null
        ? UserCard(previousData)
        : const CircularProgressIndicator(),
    Success(:final data) => UserCard(data),
    Failure(:final error) => ErrorScreen(error),
  },
)
```

---

## Capabilities

| Feature                | Description                                                              |
| ---------------------- | ------------------------------------------------------------------------ |
| Automatic caching      | Data is stored and served instantly on repeat requests                   |
| Stale-while-revalidate | Show cached data immediately, refetch silently in background             |
| Request deduplication  | 10 widgets, same key → 1 network call                                    |
| Automatic retry        | Failed requests retry with exponential backoff                           |
| Optimistic updates     | Update the UI before the server responds, roll back on failure           |
| Reactive invalidation  | Invalidate a key → every subscriber rebuilds automatically               |
| Infinite queries       | Bi-directional pagination with `fetchNextPage` / `fetchPreviousPage`     |
| Offline support        | Queue mutations offline, replay on reconnect; `NetworkMode` per-query    |
| Persistence            | `PersistQoraClient`: hydrate the cache from storage on startup          |

---

## Packages

| Package | CI | Likes | Downloads | Analysis |
| ------- | -- | ----- | --------- | -------- |
| [![qora](https://img.shields.io/pub/v/qora.svg?label=qora)](https://pub.dev/packages/qora) | [![build](https://github.com/meragix/qora/actions/workflows/dart.yml/badge.svg?branch=main)](https://github.com/meragix/qora/actions/workflows/dart.yml) | [![likes](https://img.shields.io/pub/likes/qora)](https://pub.dev/packages/qora/score) | [![dm](https://img.shields.io/pub/dm/qora)](https://pub.dev/packages/qora/score) | [![pub points](https://img.shields.io/pub/points/qora)](https://pub.dev/packages/qora/score) |
| [![qora_flutter](https://img.shields.io/pub/v/qora_flutter.svg?label=qora_flutter)](https://pub.dev/packages/qora_flutter) | [![build](https://github.com/meragix/qora/actions/workflows/flutter.yml/badge.svg?branch=main)](https://github.com/meragix/qora/actions/workflows/flutter.yml) | [![likes](https://img.shields.io/pub/likes/qora_flutter)](https://pub.dev/packages/qora_flutter/score) | [![dm](https://img.shields.io/pub/dm/qora_flutter)](https://pub.dev/packages/qora_flutter/score) | [![pub points](https://img.shields.io/pub/points/qora_flutter)](https://pub.dev/packages/qora_flutter/score) |
| [![qora_hooks](https://img.shields.io/pub/v/qora_hooks.svg?label=qora_hooks)](https://pub.dev/packages/qora_hooks) | [![build](https://github.com/meragix/qora/actions/workflows/hooks.yml/badge.svg?branch=main)](https://github.com/meragix/qora/actions/workflows/hooks.yml) | [![likes](https://img.shields.io/pub/likes/qora_hooks)](https://pub.dev/packages/qora_hooks/score) | [![dm](https://img.shields.io/pub/dm/qora_hooks)](https://pub.dev/packages/qora_hooks/score) | [![pub points](https://img.shields.io/pub/points/qora_hooks)](https://pub.dev/packages/qora_hooks/score) | 
| [![qora_devtools_overlay](https://img.shields.io/pub/v/qora_devtools_overlay.svg?label=qora_devtools_overlay)](https://pub.dev/packages/qora_devtools_overlay) | [![build](https://github.com/meragix/qora/actions/workflows/overlay.yml/badge.svg?branch=main)](https://github.com/meragix/qora/actions/workflows/overlay.yml) | [![likes](https://img.shields.io/pub/likes/qora_devtools_overlay)](https://pub.dev/packages/qora_devtools_overlay/score) | [![dm](https://img.shields.io/pub/dm/qora_devtools_overlay)](https://pub.dev/packages/qora_devtools_overlay/score) | [![pub points](https://img.shields.io/pub/points/qora_devtools_overlay)](https://pub.dev/packages/qora_devtools_overlay/score) |

<!-- | [![qora_devtools_extension](https://img.shields.io/pub/v/qora_devtools_extension.svg?label=qora_devtools_extension)](https://pub.dev/packages/qora_devtools_extension) | [![build](https://github.com/meragix/qora/actions/workflows/extension.yml/badge.svg?branch=main)](https://github.com/meragix/qora/actions/workflows/extension.yml) | [![likes](https://img.shields.io/pub/likes/qora_devtools_extension)](https://pub.dev/packages/qora_devtools_extension/score) | [![dm](https://img.shields.io/pub/dm/qora_devtools_extension)](https://pub.dev/packages/qora_devtools_extension/score) | [![pub points](https://img.shields.io/pub/points/qora_devtools_extension)](https://pub.dev/packages/qora_devtools_extension/score) | -->

---

## Install

```yaml
# Flutter app: qora is included automatically
dependencies:
  qora_flutter: ^1.0.0
```

```yaml
# Pure Dart (CLI, backend, shared package)
dependencies:
  qora: ^1.0.0
```

```yaml
# DevTools overlay (in-app panel): in dev_dependencies; not included in release builds
dev_dependencies:
  qora_devtools_overlay: ^1.0.0
```

```yaml
# DevTools extension (IDE): under development, not yet published on pub.dev
# dependencies:
#   qora_devtools_extension: ^1.0.0
```

Setup:

```dart
void main() {
  final tracker = OverlayTracker();
  final client = QoraClient(tracker: tracker);

  runApp(
    QoraInspector(
      tracker: tracker,
      client: client,
      child: QoraScope(
        client: client,
        child: const MyApp(),
      ),
    ),
  );
}
```

---

## DevTools

Qora ships with first-class developer tooling across two surfaces.

**In-app overlay** *(stable)*: a draggable panel that lives inside your running app, similar to TanStack Query's overlay. Add `qora_devtools_overlay` to `dev_dependencies` and wrap your app with `QoraInspector`. Zero overhead in release, the widget tree is never built outside of debug mode.

**IDE extension** *(under development, not yet published)*: a native tab inside Flutter DevTools (VS Code / IntelliJ) with six panels: live query inspector, mutation timeline, mutation inspector, network activity monitor, performance metrics, and a query dependency graph. The package is not yet available on pub.dev. Use the in-app overlay in the meantime.

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
melos test

# Analyze all packages
melos analyze
```

---

Built for the Dart community.
