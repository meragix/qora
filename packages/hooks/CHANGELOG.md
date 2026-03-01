# Changelog

## [Unreleased]

## [0.5.0] - 2026-03-01

### Changed

- Updated dependency to `flutter_qora: ^0.5.0` for suite alignment with core 0.5.0 persistence release

## [0.1.0] - 2026-02-28

### Added

- `useQueryClient()` — reads the nearest `QoraClient` from the widget tree via
  `QoraScope.of(context)`.
- `useQuery<T>()` — subscribes to a `QoraClient` query and returns the current
  `QoraState<T>`; auto-fetches on mount, re-subscribes on key change, and
  initialises from the cache for zero-loading-flash renders.
- `useMutation<TData, TVariables>()` — wraps `MutationController` and returns a
  `MutationHandle` with `.mutate()`, `.mutateAsync()`, `.reset()`, and typed
  state helpers (`isIdle`, `isPending`, `isSuccess`, `isError`, `data`, `error`).
- `useInfiniteQuery<TData, TPageParam>()` — pagination hook that accumulates
  pages; exposes `fetchNextPage()`, `hasNextPage`, `isFetchingNextPage`, and
  `isLoading`.
- `MutationHandle<TData, TVariables>` — value object grouping mutation state
  and action callbacks.
- `InfiniteQueryHandle<TData, TPageParam>` — value object grouping infinite
  query state and the `fetchNextPage` callback.
- Added `flutter_qora` path dependency to support `QoraScope.of` in
  `useQueryClient`.
- Widget tests covering all four hooks.
