# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Polymorphic key system supporting key: [] AND QoraKey
- Deep recursive equality with order-independent map support
- Defensive immutability via List.unmodifiable()
- Custom KeyCacheMap to avoid reference traps

### Change

- Update old QoraState implementation system
- Update old QoraKey implementation system

## [0.1.0] - 2026-02-11

### Added

- QoraClient with in-memory caching
- QoraKey with deep equality
- CachedEntry structure
- QoraOptions and QoraClientConfig configuration
- Stale-while-revalidate caching strategy
- Query deduplication
- getQueryData / setQueryData
- Retry logic with exponential backoff

[unreleased]: https://github.com/meragix/qora/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/meragix/qora/releases/tag/qora-0.1.0
