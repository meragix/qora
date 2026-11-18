<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [1.4.1] - 2026-11-17

### Changed

- Requires `qora` 1.4.1.

## [1.4.0] - 2026-11-17

### Added

- `MutationQueueBuilder` rebuilds with the calls in the mutation queue.

### Changed

- `QoraMutationBuilder.mutator` is optional (now nullable) for registered mutations.

## [1.3.1] - 2026-11-07

- No changes in this package. Released in lockstep with `qora` 1.3.1 and `qora_hooks` 1.3.1.

## [1.3.0] - 2026-11-07

### Added

- `QoraScope.auto()` wires refetch on app resume and on reconnect.
- `QoraBuilder.select` rebuilds only when the selected value changes.
- `QoraBuilder` renders `initialData` or `placeholderData` on the first frame.

### Fixed

- A fetcher failing synchronously no longer causes an endless refetch loop.
- Builders render cached data on the first frame instead of `Initial`.
- A new key list with the same content no longer refetches.

## [1.2.0] - 2026-06-15

### Added

- `QoraMutationBuilder` supports `MutationOptions.invalidates`.

### Fixed

- `QoraBuilder` honors `refetchOnMount`.
- `QoraStateBuilder` and `QoraPrefetch` no longer crash on first build.

## [1.1.0] - 2026-06-04

- No changes in this package. Released in lockstep with `qora` 1.1.0.

## [1.0.0] - 2026-06-01

- No changes in this package. Released in lockstep with `qora` 1.0.0.

## [0.8.0] - 2026-03-12

### Changed

- Requires `qora` 0.8.0.

## [0.7.0] - 2026-03-03

### Added

- `InfiniteQueryBuilder` for paginated lists.

## [0.6.0] - 2026-03-02

### Added

- `NetworkStatusBuilder` and `NetworkStatusIndicator` for offline UI.

### Changed

- **Breaking**: the `QoraBuilder` builder receives a third `FetchStatus` argument.
- **Breaking**: `FlutterConnectivityManager()` no longer takes a `QoraClient`.

## [0.5.0] - 2026-03-01

### Changed

- Requires `qora` 0.5.0, which adds persistence.

## [0.4.0] - 2026-02-28

### Changed

- Requires `qora` 0.4.0.

## [0.3.0] - 2026-02-25

### Added

- `MutationBuilder` widget for mutations.

## [0.2.0] - 2026-02-22

### Added

- `FlutterConnectivityManager` refetches queries on reconnect.

### Changed

- `queryKey` accepts any `Object`; `FlutterLifecycleManager.minBackgroundDuration` replaces `refetchInterval`.

## [0.1.0] - 2026-02-11

### Added

- First release: `QoraScope`, `QoraBuilder`, `QoraStateBuilder` and refetch on resume.

[unreleased]: https://github.com/meragix/qora/compare/1.1.0...HEAD
[1.1.0]: https://github.com/meragix/qora/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/meragix/qora/compare/0.8.0...1.0.0
[0.8.0]: https://github.com/meragix/qora/compare/0.7.0...0.8.0
[0.7.0]: https://github.com/meragix/qora/compare/0.6.0...0.7.0
[0.6.0]: https://github.com/meragix/qora/compare/0.5.0...0.6.0
[0.5.0]: https://github.com/meragix/qora/compare/0.4.0...0.5.0
[0.4.0]: https://github.com/meragix/qora/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/meragix/qora/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/meragix/qora/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/meragix/qora/releases/tag/0.1.0
