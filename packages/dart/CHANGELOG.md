<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.1] - 2026-11-17

### Fixed

- Failed and cancelled fetches are reported correctly to DevTools.
- `setQueryData` sends serialized data to DevTools.
- A throwing `QoraOptions.toJson` no longer breaks fetches when DevTools are attached.

## [1.4.0] - 2026-11-17

### Added

- `QoraClient.registerMutation` and `MutationOptions.mutationKey`: register a mutation once, run it anywhere.
- `QoraClient.mutationQueue`: offline writes queued, retried, ordered by `scope`; `PersistQoraClient` persists it.
- `MutationMeta.mutationId`, stable across retries, to send as an idempotency key.
- `MutationDiscardedException` passed to `onError` when the app discards a queued call.
- `QueryCache(canEvict:)` keeps chosen entries from LRU eviction.

### Changed

- `prefetch()` no longer throws on failure; use `fetchQuery` to catch errors.
- `onBackgroundFetchError` fires once per failed background fetch, not on cancellation or offline pause.
- `PersistQoraClient.clearStorage()` deletes only Qora's keys; call `StorageAdapter.clear()` to wipe all.

### Deprecated

- `OfflineMutationQueue.stopOnFirstError`: it never worked; use a mutation `scope`.

### Fixed

- Per-query `QoraOptions` now inherit `defaultOptions`; pass a default explicitly to keep the old reset.
- Per-query `gcTime` is now applied.
- Infinite queries respect `retryCondition` and stop retrying after `dispose()`.
- A failed fetch on reconnect no longer crashes the app or skips the replay.
- Queries no longer get stuck in `Loading` after a cancel or a throwing transform.
- A slow superseded fetch no longer overwrites newer data or a removed query.
- Cache eviction fixes: in-flight results kept, `maxCacheSize` enforced, lazy eviction works.

## [1.3.1] - 2026-11-07

### Fixed

- `hydrate()` no longer deletes app keys stored in the same adapter.

## [1.3.0] - 2026-11-07

### Added

- `invalidatePrefix(prefix)` invalidates every query whose key starts with `prefix`.
- `prepopulateCache()` seeds the cache from `initialData` or `placeholderData`.

### Fixed

- Active watchers now refetch when their query is invalidated.

## [1.2.0] - 2026-06-15

### Added

- `QoraOptions.structuralSharing` (default on) keeps unchanged data references to avoid rebuilds.
- Tag-based invalidation: `providesTags`, `invalidatesTags`, `invalidateTags()`.
- `MutationOptions.invalidates` invalidates query keys after a successful mutation.
- `QoraOptions.transform` and `transformError` reshape data and errors outside the fetcher.
- `QoraOptions.keepPreviousData` keeps showing data while refetching.
- `MutationOptions.retryCondition` and `QoraClient.clearCache()`.

### Changed

- **Breaking**: persistence TTL `null` now means forever and `Duration.zero` disables persistence.

### Fixed

- `watchQuery` no longer drops its initial `Loading` state.
- `hydrate()` deletes orphaned entries with no serializer.

## [1.1.0] - 2026-06-04

### Added

- `QoraClientConfig.onBackgroundFetchError` to log background fetch failures.

### Changed

- `mapSuccess` renamed to `mapData`, `debounceLoading` renamed to `delayLoading`.

### Fixed

- Background fetch errors no longer crash the app.
- `delayLoading` no longer delays `Success` states.
- `registerSerializer` without a name now throws in release builds too.
- `combine` helpers keep the oldest `updatedAt`.

## [1.0.0] - 2026-06-01

### Fixed

- `Failure.hashCode` and a `watchFetchStatus` stream leak.

## [0.9.0] - 2026-06-01

### Added

- `hasActiveWatcher()` and `QoraTracker.needsSerialization`.

### Changed

- **Breaking**: `MutationEvent` renamed to `MutationUpdate`.
- **Breaking**: custom `QoraTracker` classes must add `needsSerialization` and `onQueryFetched(dependsOnKey:)`.

### Fixed

- `refetchOnWindowFocus` now works: `QoraScope` wires the lifecycle manager.
- Clear error when one key is used with two data types; stream and timer leaks.

## [0.8.0] - 2026-03-12

### Added

- `QoraClient.markStale()` flags a query stale without refetching.

### Fixed

- `debugSetQueryError()` no longer throws a `TypeError`.

## [0.7.0] - 2026-03-03

### Added

- Infinite queries: `InfiniteQueryObserver`, `InfiniteData`, `InfiniteQueryState`.
- `CancelToken` cancels a fetch and restores the previous state.
- `QoraOptions.dependsOn`, `invalidateQueries(filter:)` and Flutter Web `SsrHydrator`.

## [0.6.0] - 2026-03-02

### Added

- Offline support: `NetworkMode`, `FetchStatus`, `OfflineMutationQueue`, optimistic responses.

## [0.5.0] - 2026-03-01

### Added

- `PersistQoraClient`: persist queries to a `StorageAdapter` and restore them on startup.

### Fixed

- Persisted `Failure` states are restored correctly.

## [0.4.0] - 2026-02-28

### Added

- `QoraTracker`, an observability interface for DevTools.

## [0.3.0] - 2026-02-25

### Added

- Mutations: `MutationController`, `MutationState`, lifecycle callbacks, `mutationEvents`.

### Changed

- `MutationFunction` renamed to `MutatorFunction`.

## [0.2.0] - 2026-02-22

### Added

- `prefetch`, `watchState`, `removeQuery`, `clear` and optimistic rollback.

### Changed

- **Breaking**: sealed `QoraState`, keys accept any `Object`, `invalidate()` and `invalidateWhere()` replace `invalidateQuery()` and `invalidateQueries()`.

## [0.1.0] - 2026-02-11

### Added

- First release: cache, stale-while-revalidate, deduplication and retries.

[unreleased]: https://github.com/meragix/qora/compare/1.4.1...HEAD
[1.4.1]: https://github.com/meragix/qora/compare/1.4.0...1.4.1
[1.4.0]: https://github.com/meragix/qora/compare/1.3.1...1.4.0
[1.3.1]: https://github.com/meragix/qora/compare/1.3.0...1.3.1
[1.3.0]: https://github.com/meragix/qora/compare/1.2.0...1.3.0
[1.2.0]: https://github.com/meragix/qora/compare/1.1.0...1.2.0
[1.1.0]: https://github.com/meragix/qora/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/meragix/qora/compare/0.9.0...1.0.0
[0.9.0]: https://github.com/meragix/qora/compare/0.8.0...0.9.0
[0.8.0]: https://github.com/meragix/qora/compare/0.7.0...0.8.0
[0.7.0]: https://github.com/meragix/qora/compare/0.6.0...0.7.0
[0.6.0]: https://github.com/meragix/qora/compare/0.5.0...0.6.0
[0.5.0]: https://github.com/meragix/qora/compare/0.4.0...0.5.0
[0.4.0]: https://github.com/meragix/qora/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/meragix/qora/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/meragix/qora/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/meragix/qora/releases/tag/0.1.0
