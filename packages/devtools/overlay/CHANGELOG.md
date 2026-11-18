<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.4.0] - 2026-11-17

### Added

- Queue tab for `client.mutationQueue`; needs `QoraInspector(client:)`.

### Changed

- Requires `qora` 1.4.1 and `qora_devtools_shared` 0.3.0.

### Fixed

- Compiles again: 0.3.0 used unpublished `qora_devtools_shared` APIs.
- Failed and cancelled fetches no longer stay `loading`.
- `setQueryData`, errors and `clear()` now show in the panel as in the cache.

### Removed

- Buttons, fields and tabs that did nothing or showed made-up values.
- `OverlayTracker.onOptimistic` and `OverlayTracker.cacheSnapshot`.

## [0.3.0] - 2026-11-07

### Added

- `QoraInspector(client:)` adds Refetch, Invalidate, Remove, Mark Stale and Simulate Error actions.

### Fixed

- Installable with `qora` 1.x and current Flutter.
- Status dots update on fetch, invalidation and removal.
- The search field no longer throws on focus.

## [0.2.0] - 2026-03-12

### Added

- Data Diff tab for mutations.

## [0.1.0] - 2026-02-28

### Added

- First release: `QoraInspector` with queries, mutations and timeline panels.
