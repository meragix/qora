<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

## [Unreleased]

### Fixed

- `useInfiniteQuery`: `fetchNextPage` called the fetcher once and exposed the first failure, while the first page went through `fetchQuery` and was retried. It now applies the same policy: `retryCount`, `retryCondition` and the backoff of `options`, merged over the client defaults.
- `useInfiniteQuery`: `error` kept the last failure after a page loaded successfully; it is now cleared.
- `useInfiniteQuery`: a page that arrived after the key changed was appended to the new key's pages, and a page that arrived after unmount threw "A ValueNotifier was used after being disposed". Late results are now dropped, and retries stop once the key changes or the widget unmounts.

## [1.3.1] - 2026-11-07

### Fixed

- `useMutation` now uses the offline mutation queue: with `MutationOptions(offlineQueue: true)`, a call made while offline is queued and sent on reconnect, as with `QoraMutationBuilder`. It was previously sent immediately and failed.
- `useMutation` now reports its mutations to the client, so they appear in the DevTools overlay and in `QoraClient.mutationEvents`.

## [1.3.0] - 2026-11-07

### Added

- `useFetchStatus(key)`: exposes the `FetchStatus` axis (fetching / paused / idle) of a query to hooks, so a hook-based UI can show a background-refresh indicator or an offline badge independently of the data state.
- `qora_hooks` now re-exports `FetchStatus`, `QoraException`, `QoraKey`, `QueryTag` and the `MutationState` family, so hook users no longer need a second `qora_flutter` import for common types.
- `useQuery` seeds `QoraOptions.initialData` / `placeholderData` before the first build (#19).
- `useQuery(select: ...)`: rebuild filter for derived data. The hook triggers a rebuild only when the state kind or the selected value changes and always returns the latest state (#22).

### Fixed

- `useQuery`: refetches after its query is invalidated instead of staying in `Loading(previousData)` (fixed in `qora` core).
- `useQuery`: background refetches use the latest `fetcher` closure instead of the one captured on first subscription.
- `useQuery`: on key change, the first build reads the new key's cache instead of returning the previous key's state.

## [1.2.0] - 2026-06-15

## [1.1.0] - 2026-06-04

### Added

- `pubspec.yaml` : added `topics` field.

### Fixed

- `useQuery` / `useInfiniteQuery` : `Object.hashAll(key)` in `useEffect` dependency array caused hash collisions where different query keys produced the same hash, skipping re-subscription; replaced with a `_QueryKey` wrapper using deep equality.

## [1.0.0] - 2026-06-01

### Changed

- Bump version to 1.0.0 to align with `qora` core package for the v1.0.0 release.

## [0.8.0] - 2026-03-01

### Changed

- Updated dependency to `qora_flutter: ^0.8.0` for suite alignment with core 0.8.0 persistence release

## [0.7.0] - 2026-03-02

### Added

- `useIsFetching()` : returns `true` while at least one query managed by the
  nearest `QoraClient` has a network request in flight. Initialises
  synchronously from `QoraClient.isFetchingCount` and subscribes to the new
  `QoraClient.fetchingCountStream` for reactive updates.
- `useIsMutating()` : returns `true` while at least one mutation managed by the
  nearest `QoraClient` is in `MutationPending` state. Initialises from
  `QoraClient.activeMutations` and subscribes to `QoraClient.mutationEvents`.

## [0.5.0] - 2026-03-01

### Changed

- Updated dependency to `qora_flutter: ^0.5.0` for suite alignment with core 0.5.0 persistence release

## [0.1.0] - 2026-02-28

### Added

- `useQueryClient()` : reads the nearest `QoraClient` from the widget tree via
  `QoraScope.of(context)`.
- `useQuery<T>()` : subscribes to a `QoraClient` query and returns the current
  `QoraState<T>`; auto-fetches on mount, re-subscribes on key change, and
  initialises from the cache for zero-loading-flash renders.
- `useMutation<TData, TVariables>()` : wraps `MutationController` and returns a
  `MutationHandle` with `.mutate()`, `.mutateAsync()`, `.reset()`, and typed
  state helpers (`isIdle`, `isPending`, `isSuccess`, `isError`, `data`, `error`).
- `useInfiniteQuery<TData, TPageParam>()` : pagination hook that accumulates
  pages; exposes `fetchNextPage()`, `hasNextPage`, `isFetchingNextPage`, and
  `isLoading`.
- `MutationHandle<TData, TVariables>` : value object grouping mutation state
  and action callbacks.
- `InfiniteQueryHandle<TData, TPageParam>` : value object grouping infinite
  query state and the `fetchNextPage` callback.
- Added `qora_flutter` path dependency to support `QoraScope.of` in
  `useQueryClient`.
- Widget tests covering all four hooks.

[unreleased]: https://github.com/meragix/qora/compare/1.1.0...HEAD
[1.1.0]: https://github.com/meragix/qora/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/meragix/qora/compare/0.8.0...1.0.0
[0.8.0]: https://github.com/meragix/qora/compare/0.7.0...0.8.0
[0.7.0]: https://github.com/meragix/qora/compare/0.5.0...0.7.0
[0.5.0]: https://github.com/meragix/qora/compare/0.1.0...0.5.0
[0.1.0]: https://github.com/meragix/qora/releases/tag/0.1.0
