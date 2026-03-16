<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.3.0] - 2026-03-16

### Added

- `QoraExtensionMethods.protocolVersion` — `'1.0.0'` wire-protocol version constant; bump policy: major on breaking schema changes, minor on additive changes, patch on fixes.
- `QoraExtensionMethods.getVersion` — `'ext.qora.getVersion'` constant for the version-handshake extension method.
- `QueryEvent.dependsOnKey` — nullable `String?` field on `QueryEvent.fetched` events carrying the JSON-encoded key of the `QoraOptions.dependsOn` dependency; enables DevTools to draw authoritative query→query edges without temporal heuristics.

## [0.2.0] - 2026-03-12

### Added

- **`QueryEvent.fetchDurationMs`** — nullable `int` field on `QueryEvent.fetched` events carrying the wall-clock duration (milliseconds) between fetch-started and fetch-completed; `null` when timing data is unavailable (e.g. legacy trackers or events replayed from the ring buffer without a recorded start time).

## [0.1.0] - 2026-02-28

### Added

- `TimelineEventType` enum with `displayName` getter and 8 variants (optimisticUpdate, mutationStarted/Success/Error, fetchStarted/Error, queryCreated, cacheCleared)
- `TimelineEvent` — immutable record with `type`, `key?`, `mutationId?`, `timestamp` fields; used by `OverlayTracker` ring buffer

- Initial implementation of the shared DevTools protocol package.
- Added typed events:
  - `QoraEvent` base contract with `GenericQoraEvent` fallback.
  - `QueryEvent` with lifecycle variants and lazy-payload metadata.
  - `MutationEvent` with started/settled lifecycle helpers.
- Added command contracts:
  - `QoraCommand` base interface.
  - `RefetchCommand`, `InvalidateCommand`.
  - `RollbackOptimisticCommand`, `GetCacheSnapshotCommand`, `GetPayloadChunkCommand`.
- Added protocol codecs:
  - `EventCodec` for robust event decoding/encoding.
  - `CommandCodec` with support for both short and fully-qualified extension methods.
- Added snapshot DTOs:
  - `QuerySnapshot`, `MutationSnapshot`, `CacheSnapshot`.
- Added centralized protocol constants:
  - VM extension methods (`ext.qora.*`) and extension event names.
- Updated package barrel exports for commands, codecs, events, models, and protocol constants.
- Added unit tests covering:
  - Event decoding,
  - Command decoding,
  - Snapshot serialization roundtrip.
