<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.7.0] - 2026-03-03

### Added

- **`InfiniteQueryBuilder<TData, TPageParam>`** — `StatefulWidget` that manages the full infinite-query lifecycle: creates an `InfiniteQueryObserver` on mount, fetches the first page, subscribes to all state transitions, and disposes cleanly; auto-refetches on `InfiniteInitial` (external invalidation); accepts `queryKey`, `fetcher`, `options`, `builder`, `client`, and `enabled`
- **`InfiniteQueryController<TData, TPageParam>`** — stable handle passed to the builder with `fetchNextPage()`, `fetchPreviousPage()`, and `refetch()`; safe to capture in scroll listeners and `RefreshIndicator.onRefresh`

## [0.6.0] - 2026-03-02

### Added

- **`NetworkStatusBuilder`** — low-level widget that subscribes to the `ConnectivityManager` stream and rebuilds on every `NetworkStatus` transition; accepts optional `child` to avoid rebuilding expensive sub-trees
- **`NetworkStatusIndicator`** — high-level wrapper that overlays an offline banner on `NetworkStatus.offline`; built-in default banner (wifi-off icon, "Offline mode" text, no Material dependency); customisable via `offlineBanner` or full `builder` escape-hatch
- **`QoraScope.connectivityManagerOf(context)`** — static method exposing the active `ConnectivityManager` to descendant widgets; used internally by `NetworkStatusBuilder`
- **`QoraMutationBuilder`** — now injects `isOnline` callback and `offlineMutationQueue` from `QoraClient` into `MutationController` automatically
- **`QoraBuilder`** — builder signature extended to three arguments `(BuildContext, QoraState<T>, FetchStatus)`; subscribes to `client.watchFetchStatus(key)` alongside state stream; catches `QoraOfflineException` silently (handled via `FetchStatus.paused`)

### Changed

- **`FlutterConnectivityManager`** — now a **pure signal provider**; constructor takes no arguments; removed `QoraClient` dependency and direct `invalidateWhere()` call; all reconnect logic delegated to `QoraClient.attachConnectivityManager()`
- **`QoraScope`** — calls `client.attachConnectivityManager(cm)` after `connectivityManager.start()` in `initState`; exposes manager via `_InheritedQoraScope`

## [0.5.0] - 2026-03-01

### Changed

- Updated dependency to `qora: ^0.5.0` — enables `PersistQoraClient`, `StorageAdapter`, `QoraSerializer`, and the full persistence layer introduced in core 0.5.0

## [0.4.0] - 2026-02-28

### Changed

- Updated dependencies to `qora: ^0.4.0` in `qora_flutter` package
- Updated README and documentation to reflect new version and features

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
- `FlutterConnectivityManager` and `FlutterLifecycleManager` exported from the main `qora_flutter` library barrel
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
