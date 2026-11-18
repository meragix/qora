<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

## [Unreleased]

## [1.4.1] - 2026-11-17

### Changed

- Requires `qora_flutter` 1.4.1.

## [1.4.0] - 2026-11-17

### Added

- `useMutationQueue()` returns the calls in the mutation queue.

### Changed

- `useMutation`'s `mutator` is optional for registered mutations.

### Fixed

- `useInfiniteQuery` retries next pages like the first one and clears `error` after a success.
- `useInfiniteQuery` drops pages that arrive after a key change or unmount.

## [1.3.1] - 2026-11-07

### Fixed

- `useMutation` queues offline calls with `offlineQueue: true` and reports to DevTools.

## [1.3.0] - 2026-11-07

### Added

- `useFetchStatus(key)` exposes fetching, paused or idle.
- `useQuery(select:)` rebuilds only when the selected value changes.
- `useQuery` renders `initialData` or `placeholderData` on the first build.
- Common types re-exported: no second `qora_flutter` import needed.

### Fixed

- `useQuery` refetches after invalidation and reads the new key's cache on key change.

## [1.2.0] - 2026-06-15

- No changes in this package. Released in lockstep with `qora` 1.2.0.

## [1.1.0] - 2026-06-04

### Fixed

- Different query keys no longer share a subscription.

## [1.0.0] - 2026-06-01

- No changes in this package. Released in lockstep with `qora` 1.0.0.

## [0.8.0] - 2026-03-12

### Changed

- Requires `qora_flutter` 0.8.0.

## [0.7.0] - 2026-03-02

### Added

- `useIsFetching()` and `useIsMutating()`.

## [0.5.0] - 2026-03-01

### Changed

- Requires `qora_flutter` 0.5.0.

## [0.1.0] - 2026-02-28

### Added

- First release: `useQuery`, `useMutation`, `useInfiniteQuery` and `useQueryClient`.

[unreleased]: https://github.com/meragix/qora/compare/1.1.0...HEAD
[1.1.0]: https://github.com/meragix/qora/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/meragix/qora/compare/0.8.0...1.0.0
[0.8.0]: https://github.com/meragix/qora/compare/0.7.0...0.8.0
[0.7.0]: https://github.com/meragix/qora/compare/0.5.0...0.7.0
[0.5.0]: https://github.com/meragix/qora/compare/0.1.0...0.5.0
[0.1.0]: https://github.com/meragix/qora/releases/tag/0.1.0
