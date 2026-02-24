<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-02-24

### Added

- **`MutationController<TData, TVariables, TContext>`** — standalone controller managing the full mutation lifecycle: `MutationIdle → MutationPending → MutationSuccess | MutationFailure`
- **`MutationState<TData, TVariables>`** — sealed class hierarchy with four variants: `MutationIdle`, `MutationPending`, `MutationSuccess`, `MutationFailure`; each carries typed `variables` for full traceability
- **`MutationOptions<TData, TVariables, TContext>`** — per-mutation configuration with lifecycle callbacks:
  - `onMutate(variables)` — called before the mutator; return value becomes `TContext` (snapshot for rollback)
  - `onSuccess(data, variables, context)` — called on success
  - `onError(error, variables, context)` — called on failure; use `context` to roll back optimistic updates via `restoreQueryData`
  - `onSettled(data, error, variables, context)` — called after either outcome
  - `retryCount` / `retryDelay` — optional retry with exponential backoff (default: 0 retries)
- **`MutatorFunction<TData, TVariables>`** typedef — mirrors `QueryFunction<T>` for consistency (`mutator` parameter naming mirrors `fetcher`)
- `MutationStateExtensions` — `fold<R>()` exhaustive mapper and `status` getter returning `MutationStatus` enum
- `MutationStatus` enum — coarse-grained `idle | pending | success | error` values with boolean getters
- `MutationStateStreamExtensions` — `whereSuccess()`, `whereError()`, `dataOrNull()` stream operators

### Changed

- **`MutationFunction` renamed to `MutatorFunction`** — aligns naming with the `fetcher`/`mutator` parameter convention used throughout the API

## [0.2.0] - 2026-02-22

### Added

- `watchState<T>(Object key)` — observe-only stream that subscribes to a query's state without triggering any fetch; ideal for derived UI components (e.g. badges, avatar widgets)
- `prefetch<T>()` — pre-warm the cache before navigation without blocking the UI; no-op if data is already fresh
- `restoreQueryData<T>(key, snapshot)` — roll back an optimistic update; removes the entry from cache if snapshot is `null`
- `removeQuery(key)` — evict a single query from cache and cancel any pending request for it
- `clear()` — evict all cached queries and cancel all in-flight requests (e.g. on user logout)
- `cachedKeys` getter — returns all currently cached normalised query keys for debugging or bulk operations
- `debugInfo()` — returns a map snapshot of cache and pending-request counts

### Changed

- **`QoraState<T>` rewritten as a sealed class** — four exhaustive variants: `Initial | Loading | Success | Failure`. `Loading` and `Failure` now carry `previousData` for graceful degradation (stale data shown during refetch or on error)
- **Polymorphic key system** — `fetchQuery`, `watchQuery`, `watchState`, `prefetch`, `setQueryData`, `restoreQueryData`, `invalidate`, `getQueryData`, and `getQueryState` now accept `Object` (plain `List<dynamic>` **or** `QoraKey`); keys are normalised and compared with deep structural equality
- **`KeyCacheMap`** — custom map implementation with deep recursive equality and order-independent map-key comparison; eliminates reference-equality bugs
- **`invalidate(key)`** replaces the old `invalidateQuery(key)`
- **`invalidateWhere(predicate)`** replaces the old `invalidateQueries(predicate)`; predicate receives the normalised `List<dynamic>` key
- **Package structure reorganised** — source files split into `cache/`, `config/`, `client/`, `key/`, `state/`, and `utils/` subdirectories for clarity

### Fixed

- Defensive immutability: normalised key lists are wrapped in `List.unmodifiable()` to prevent accidental mutation by callers

## [0.1.0] - 2026-02-11

### Added

- `QoraClient` with in-memory caching
- `QoraKey` with deep equality
- `CachedEntry` structure
- `QoraOptions` and `QoraClientConfig` configuration
- Stale-while-revalidate (SWR) caching strategy
- Query deduplication
- `getQueryData` / `setQueryData`
- Retry logic with exponential backoff

[unreleased]: https://github.com/meragix/qora/compare/0.3.0...HEAD
[0.3.0]: https://github.com/meragix/qora/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/meragix/qora/releases/tag/0.2.0
[0.1.0]: https://github.com/meragix/qora/releases/tag/0.1.0
