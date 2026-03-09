<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `CacheEntry.setError(Object error)` — transitions an entry to `Failure<T>` using the entry's own reified `T`; eliminates the `Failure<dynamic>` cast error that occurred when `debugSetQueryError` used an untyped cache lookup.
- `CacheEntry.markStale()` — sets an internal `_forcedStale` flag without pushing any state update to observers; `isStale()` now returns `true` whenever `_forcedStale` is set, regardless of `staleTime`; the flag is cleared by `updateState()`.
- `QoraClient.markStale(Object key)` — silently flags a cache entry stale without transitioning to `Loading` or triggering an immediate refetch; active observers see no change; the next `fetchQuery` / `watchQuery` mount will see `isStale() == true` and trigger an SWR background revalidation.
- `QoraTracker.onQueryRemoved(String key)` — hook called when `removeQuery` evicts a cache entry; `NoOpTracker` ships an empty override.
- `QoraTracker.onQueryMarkedStale(String key)` — hook called when `markStale` silently flags an entry; differs from `onQueryInvalidated` in that no state transition or timeline fetch entry is implied; `NoOpTracker` ships an empty override.

### Fixed

- `QoraClient.debugSetQueryError()` — previously called `_cache.get<dynamic>()` and pushed `Failure<dynamic>` into a `StreamController<QoraState<T>>`, causing a `TypeError` at runtime; now uses `_cache.peek()` and delegates to `CacheEntry.setError()` so the `Failure` is instantiated with the correct reified `T`.
- `QoraClient.removeQuery()` — did not notify the tracker; now calls `_tracker.onQueryRemoved(sk)` so DevTools overlays remove the corresponding row immediately.

## [0.7.0] - 2026-03-03

### Added

- `CancelToken` — cooperative cancellation for `fetchQuery`, `watchQuery`, and `prefetch`; state restored to pre-fetch snapshot on cancellation
- `QoraCancelException` — thrown to the caller when a fetch is cancelled via `CancelToken`
- `QoraTracker.onQueryCancelled(String key)` — hook called when a fetch is cancelled; `NoOpTracker` ships an empty override
- `QueryFilter` typedef — `bool Function(String key, QoraState<dynamic> state, QoraOptions? lastOptions)` — richer invalidation predicate
- `QoraClient.invalidateQueries({required QueryFilter filter})` — bulk invalidation using `QueryFilter`
- `CacheEntry.lastOptions` — records the options from the last successful fetch; used by `invalidateQueries`
- `QoraOptions.dependsOn` — declares a query dependency; `watchQuery` fires reactively when the dependency resolves, `fetchQuery` throws `StateError` if unresolved, `prefetch` silently skips
- `QoraClient.queueHydration(key, data, {updatedAt})` — enqueue a pre-deserialized value for lazy typed injection; shared hydration mechanism for `PersistQoraClient` and `SsrHydrator`
- `QoraClient.removeHydrationEntry(key)` — `@protected`; removes a pending hydration entry
- `QoraClient.clearHydrationQueue()` — `@protected`; clears all pending hydration entries
- `SsrHydrator` — Flutter Web SSR hydrator; reads `window.__QORA_STATE__`, validates strictly, and calls `queueHydration()`; XSS-safe via `dartify()` and per-deserializer try/catch; no-op stub on non-web platforms
- `QoraTracker.onQueryFetching(String key)` — hook called when a query transitions to `Loading`; pairs with `onQueryFetched` for fetch-duration tracking; `NoOpTracker` ships an empty override
- `InfiniteData<TData, TPageParam>` — immutable container for paginated pages; `append()`, `prepend()`, `dropFirst()`, `dropLast()`, `flatten()`
- `InfiniteQueryState<TData, TPageParam>` — sealed state machine: `InfiniteInitial`, `InfiniteLoading`, `InfiniteSuccess`, `InfiniteFailure`
- `InfiniteQueryOptions<TData, TPageParam>` — pagination config: `initialPageParam`, `getNextPageParam`, `getPreviousPageParam`, `maxPages`
- `InfiniteQueryObserver<TData, TPageParam>` — pagination engine: `fetch()`, `fetchNextPage()`, `fetchPreviousPage()`, `refetch()`
- `InfiniteQueryFunction<TData, TPageParam>` typedef — `Future<TData> Function(TPageParam pageParam)`
- `QoraClient.watchInfiniteState`, `getInfiniteQueryState`, `getInfiniteQueryData`, `setInfiniteQueryData`, `updateInfiniteQueryState`, `invalidateInfiniteQuery`

### Changed

- `PersistQoraClient` hydration delegated to `QoraClient` — hydration infrastructure lifted to the base class; `PersistQoraClient.hydrate()` now calls `queueHydration()`; the six typed overrides removed

## [0.6.0] - 2026-03-02

### Added

- `NetworkMode` — per-query enum (`online` / `always` / `offlineFirst`)
- `FetchStatus` — second-axis enum (`fetching` / `paused` / `idle`); observable via `QoraClient.watchFetchStatus(key)`
- `ReconnectStrategy` — thundering-herd prevention on reconnect: `maxConcurrent` + `jitter`; named constructors `instant()` and `conservative()`
- `OfflineMutationQueue` — FIFO queue for offline writes; replays on reconnect; `stopOnFirstError` flag; `OfflineReplayResult` surface
- `PendingMutation` — type-erased queued-write container
- `QoraOfflineException` — thrown by `fetchQuery` when offline with no cached data
- `QoraClient.attachConnectivityManager()` — late-attach a `ConnectivityManager`; called automatically by `QoraScope`
- `QoraClient.isOnline` / `networkStatus` — real-time connectivity getters
- `QoraClient.watchFetchStatus(key)` — stream of `FetchStatus` transitions
- `QoraClient.offlineMutationQueue` — shared `OfflineMutationQueue` instance
- `MutationSuccess.isOptimistic` — `true` when the mutation was queued offline with an `optimisticResponse`
- `MutationOptions.offlineQueue` — opt a mutation into the `OfflineMutationQueue`
- `MutationOptions.optimisticResponse` — synthetic `TData` for immediate UI feedback
- `QoraClientConfig.reconnectStrategy` — global reconnect strategy; defaults to 5 concurrent / 100 ms jitter
- `QoraOptions.networkMode` — per-query `NetworkMode`; defaults to `NetworkMode.online`

## [0.5.0] - 2026-03-01

### Added

- `PersistQoraClient` — `QoraClient` subclass that persists query results to a `StorageAdapter` and restores them on startup
- `StorageAdapter` — abstract key/value interface; ships with `InMemoryStorageAdapter`
- `QoraSerializer<T>` — `toJson`/`fromJson` pair for a type
- `PersistQoraClient.registerSerializer<T>` — register a serializer; accepts optional `name` for obfuscation safety
- `PersistQoraClient.hydrate()` — reads storage, validates TTL, queues valid entries for lazy hydration
- `PersistQoraClient.persistQuery<T>` — force-persist the current cached value with an optional TTL override
- `PersistQoraClient.evictFromStorage` / `clearStorage` — storage-only eviction
- `QoraClient.hydrateQuery<T>` — inject a typed `Success<T>` with a custom `updatedAt` into an `Initial` entry
- `QoraClient.onFetchSuccess<T>` — `@protected` hook called after every successful fetch; used by `PersistQoraClient` to auto-persist

### Fixed

- `QoraStateSerialization.toJson` wrote `'type': 'error'` for `Failure` while `fromJson` matched on `'failure'`; `Failure` states were never restored correctly

## [0.4.0] - 2026-02-28

### Added

- `QoraTracker` — abstract observability interface with lifecycle hooks for queries, mutations, and cache events
- `NoOpTracker` — default `const` implementation with zero overhead
- `QoraClient(tracker:)` — optional tracker injection; defaults to `NoOpTracker`

## [0.3.0] - 2026-02-25

### Added

- `MutationController<TData, TVariables, TContext>` — manages the full mutation lifecycle: `Idle → Pending → Success | Failure`
- `MutationState<TData, TVariables>` — sealed class: `MutationIdle`, `MutationPending`, `MutationSuccess`, `MutationFailure`; each carries typed `variables`
- `MutationOptions<TData, TVariables, TContext>` — lifecycle callbacks: `onMutate`, `onSuccess`, `onError`, `onSettled`; `retryCount` / `retryDelay`
- `MutatorFunction<TData, TVariables>` typedef
- `MutationTracker` — abstract interface implemented by `QoraClient`; decouples `MutationController` from the client
- `MutationEvent` — type-erased event on every mutation state transition; `mutatorId`, `status`, `data`, `error`, `variables`, `metadata`, `timestamp`
- `QoraClient` implements `MutationTracker` — `mutationEvents` stream, `activeMutations` snapshot; `debugInfo()` now includes `active_mutations`
- `MutationController.metadata` — `Map<String, Object?>?` forwarded to every `MutationEvent`
- `MutationController.id` — unique `mutation_N` identifier
- `MutationStateExtensions` — `fold<R>()` and `status` getter
- `MutationStatus` enum — `idle | pending | success | error`
- `MutationStateStreamExtensions` — `whereSuccess()`, `whereError()`, `dataOrNull()`

### Changed

- `MutationFunction` renamed to `MutatorFunction`

### Fixed

- `MutationController.stream` race condition — events emitted synchronously before the first microtask were lost; fixed with a `StreamController` whose `onListen` runs synchronously

## [0.2.0] - 2026-02-22

### Added

- `watchState<T>(key)` — observe-only stream; no fetch triggered
- `prefetch<T>()` — pre-warm the cache before navigation; no-op if already fresh
- `restoreQueryData<T>(key, snapshot)` — roll back an optimistic update
- `removeQuery(key)` — evict a single query and cancel any in-flight request
- `clear()` — evict all queries and cancel all in-flight requests
- `cachedKeys` — all currently cached normalised query keys
- `debugInfo()` — cache and pending-request count snapshot

### Changed

- `QoraState<T>` rewritten as a sealed class — `Initial | Loading | Success | Failure`; `Loading` and `Failure` carry `previousData`
- Polymorphic key system — all APIs now accept `Object` (plain `List<dynamic>` or `QoraKey`); deep structural equality
- `KeyCacheMap` — custom map with deep recursive equality and order-independent map-key comparison
- `invalidate(key)` replaces `invalidateQuery(key)`
- `invalidateWhere(predicate)` replaces `invalidateQueries(predicate)`
- Package structure reorganised — `cache/`, `config/`, `client/`, `key/`, `state/`, `utils/`

### Fixed

- Normalised key lists wrapped in `List.unmodifiable()` to prevent accidental mutation

## [0.1.0] - 2026-02-11

### Added

- `QoraClient` with in-memory caching
- `QoraKey` with deep equality
- `QoraOptions` and `QoraClientConfig`
- Stale-while-revalidate (SWR) caching strategy
- Query deduplication
- `getQueryData` / `setQueryData`
- Retry logic with exponential backoff

[unreleased]: https://github.com/meragix/qora/compare/0.7.0...HEAD
[0.7.0]: https://github.com/meragix/qora/compare/0.6.0...0.7.0
[0.6.0]: https://github.com/meragix/qora/compare/0.5.0...0.6.0
[0.5.0]: https://github.com/meragix/qora/compare/0.4.0...0.5.0
[0.4.0]: https://github.com/meragix/qora/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/meragix/qora/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/meragix/qora/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/meragix/qora/releases/tag/0.1.0
