# Changelog

## [Unreleased]

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
