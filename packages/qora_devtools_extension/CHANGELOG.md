## 0.0.1

* Initial implementation of the Qora runtime DevTools bridge.
* Added public package entrypoint exports for:
  * tracker (`VmTracker`),
  * command gateway (`TrackingGateway`),
  * VM extension registration/handlers,
  * lazy payload modules.
* Added VM event publisher:
  * `VmEventPusher` wrapping `developer.postEvent`.
* Added tracker implementation:
  * `VmTracker` implementing `QoraTracker`,
  * bounded in-memory ring buffer for recent events,
  * query/mutation/cache/optimistic lifecycle event emission,
  * lazy payload metadata generation for large query results.
* Added lazy payload infrastructure:
  * `PayloadChunker` for split/join operations,
  * `PayloadStore` with TTL + LRU + byte budget eviction,
  * `LazyPayloadManager` for chunked JSON retrieval.
* Added VM extension command flow:
  * `ExtensionHandlers` for refetch/invalidate/rollback/snapshot/payload chunk,
  * `ExtensionRegistrar` for registering `ext.qora.*` methods,
  * compatibility alias for legacy `ext.qora.getPayload`.
* Updated package config:
  * migrated to Dart-only package shape,
  * added `test` dev dependency and removed Flutter runtime dependency.
* Added unit tests for lazy payload handling and tracker buffer behavior.
