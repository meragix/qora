<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-02-25

### Added

- **`MutationBuilder<TData, TVariables, TContext>`** — `StatefulWidget` that creates and manages a `MutationController` internally; the `builder` receives the current `MutationState` and a `mutate(variables)` callback
  - `mutator` parameter (mirrors `fetcher` in `QoraBuilder`) — the async function performing the write
  - `options` parameter — `MutationOptions` with `onMutate` / `onSuccess` / `onError` / `onSettled` lifecycle hooks
  - `metadata` parameter — optional `Map<String, Object?>?` forwarded to every `MutationEvent`; attach domain context (e.g. `{'category': 'auth', 'screen': 'login'}`) visible in DevTools without modifying the core schema
  - Rebuilds on every state transition; controller is disposed automatically on widget unmount
  - Recreates the controller if `mutator`, `options`, or `metadata` identity changes across widget rebuilds
  - Passes `QoraScope.maybeOf(context)` as `tracker` automatically; safe to use without a `QoraScope` ancestor (standalone mode, no DevTools wiring)

## [0.2.0] - 2026-02-22

### Added

- `FlutterConnectivityManager` — invalidates all queries when the device reconnects after being offline; powered by `connectivity_plus` (bundled as a direct dependency)
- `FlutterConnectivityManager` and `FlutterLifecycleManager` exported from the main `flutter_qora` library barrel
- `QoraScope` now accepts an optional `connectivityManager` parameter alongside `lifecycleManager`

### Changed

- **`queryKey` accepts `Object`** — both `QoraBuilder` and `QoraStateBuilder` now accept a plain `List<dynamic>` or a `QoraKey`; no wrapping in `QoraKey(...)` required
- **`FlutterLifecycleManager.refetchInterval`** is now public (was `_refetchInterval`); configures the minimum background duration before queries are invalidated on app resume (default: 5 s)
- **Internal refetch mechanism** uses `client.invalidateWhere((_) => true)` instead of direct stream manipulation; active `QoraBuilder` widgets detect the resulting `Loading(previousData: …)` state and re-fetch automatically

## [0.1.0] - 2026-02-11

### Added

- `QoraScope` (`InheritedWidget`) — provides `QoraClient` to the widget tree
- `QoraBuilder<T>` — fetches on mount, subscribes to all state transitions, re-fetches on invalidation, and cleans up on dispose
- `QoraStateBuilder<T>` — observe-only variant; subscribes to state without triggering a fetch
- `BuildContext` extensions: `context.qora`, `context.qoraOrNull`
- `FlutterLifecycleManager` — invalidates all queries when the app resumes after a configurable background pause

[unreleased]: https://github.com/meragix/qora/compare/flutter_qora-v0.3.0...HEAD
[0.3.0]: https://github.com/meragix/qora/compare/flutter_qora-v0.2.0...flutter_qora-v0.3.0
[0.2.0]: https://github.com/meragix/qora/releases/tag/0.2.0
[0.1.0]: https://github.com/meragix/qora/releases/tag/0.1.0
