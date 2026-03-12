<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.2.0] - 2026-03-12

### Added

- `VmTracker.onQueryRemoved()` — implements the new `QoraTracker` hook; emits a `QueryEvent(type: removed)` to the DevTools UI so the query row is evicted from the cache inspector immediately.
- `VmTracker.onQueryMarkedStale()` — implements the new `QoraTracker` hook; emits a `QueryEvent(type: updated, status: 'stale')` so the DevTools UI shows the stale indicator without implying an active fetch.
- **`VmTracker.onQueryFetching()`** — records the fetch start timestamp (ms since epoch) per query key in an internal `_fetchStartTimes` map; cleared in `dispose()`.
- **`VmTracker.onQueryFetched()`** — now computes `fetchDurationMs` by diffing the recorded start time against the completion time and includes it in the emitted `QueryEvent.fetched`.

## [0.1.0] - 2026-02-28

### Added

- Initial implementation of the Qora runtime DevTools bridge.
- Added public package entrypoint exports for:
  - tracker (`VmTracker`),
  - command gateway (`TrackingGateway`),
  - VM extension registration/handlers,
  - lazy payload modules.
- Added VM event publisher:
  - `VmEventPusher` wrapping `developer.postEvent`.
- Added tracker implementation:
  - `VmTracker` implementing `QoraTracker`,
  - bounded in-memory ring buffer for recent events,
  - query/mutation/cache/optimistic lifecycle event emission,
  - lazy payload metadata generation for large query results.
- Added lazy payload infrastructure:
  - `PayloadChunker` for split/join operations,
  - `PayloadStore` with TTL + LRU + byte budget eviction,
  - `LazyPayloadManager` for chunked JSON retrieval.
- Added VM extension command flow:
  - `ExtensionHandlers` for refetch/invalidate/rollback/snapshot/payload chunk,
  - `ExtensionRegistrar` for registering `ext.qora.*` methods,
  - compatibility alias for legacy `ext.qora.getPayload`.
- Updated package config:
  - migrated to Dart-only package shape,
  - added `test` dev dependency and removed Flutter runtime dependency.
- Added unit tests for lazy payload handling and tracker buffer behavior.
