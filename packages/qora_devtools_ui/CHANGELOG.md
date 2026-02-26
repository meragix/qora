# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

* Initial implementation of Qora DevTools Flutter Web extension UI.
* Added VM service client integration:
  * extension event listening (`qora:event`),
  * typed event decoding via `qora_devtools_shared`,
  * command dispatch to `ext.qora.*`.
* Added repository layer:
  * `EventRepository` and `PayloadRepository` contracts,
  * runtime-backed implementations for command/event/payload operations.
* Added domain use-cases:
  * observe runtime events,
  * refetch query command,
  * fetch large payload by chunk metadata.
* Added UI state controllers:
  * timeline controller with bounded history,
  * cache controller with snapshot loading/error states.
* Added UI screens:
  * cache inspector,
  * mutation timeline,
  * optimistic updates panel.
* Added root app shell with tabs and actions (refresh cache, clear timeline).
* Added widget test for baseline app rendering.
