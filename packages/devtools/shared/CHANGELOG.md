# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
