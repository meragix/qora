/// Canonical VM service extension names and event stream keys for Qora.
///
/// All method names are centralised here to prevent string drift between the
/// runtime bridge (`qora_devtools_extension`) and the DevTools UI
/// (`qora_devtools_ui`). **Never hard-code these strings elsewhere.**
///
/// ## Naming convention
///
/// - Push events (App → UI):  `qora:<domain>` — see [QoraExtensionEvents].
/// - Pull commands (UI → App): `ext.qora.<verb><Object>` in camelCase.
///
/// ## Adding a new extension method
///
/// 1. Add a constant below following the `ext.qora.<verb><Object>` pattern.
/// 2. Register the handler in `ExtensionRegistrar.registerAll()`.
/// 3. Add a `handle<Verb>` method to `ExtensionHandlers`.
/// 4. Create a matching [QoraCommand] subclass in the `commands/` directory.
/// 5. Register the new case in [CommandCodec.decode].
/// 6. Call it from the DevTools UI via `VmServiceClient.sendCommand`.
///
/// ## Protocol versioning
///
/// [QoraExtensionMethods.protocolVersion] identifies the wire format shared
/// between the runtime bridge and the DevTools UI. The UI calls
/// [QoraExtensionMethods.getVersion] immediately after connecting and compares
/// the response major version to its own. A mismatch warns the developer that
/// the runtime and DevTools packages are out of sync.
///
/// Bump policy:
/// - **Patch** (`1.0.x`) — bug fixes, no wire format change.
/// - **Minor** (`1.x.0`) — additive fields or new extension methods.
/// - **Major** (`x.0.0`) — breaking changes; old UI cannot parse new events.
///
/// Bump the `shared` package minor version after any additive change.
abstract final class QoraExtensionMethods {
  /// VM service extension name prefix.
  static const String prefix = 'ext.qora';

  /// Semantic version of the Qora DevTools wire protocol.
  ///
  /// Both sides of the bridge import this constant from the shared package, so
  /// they always agree on what the current version string should be.
  ///
  /// [VmServiceClient] queries this via [getVersion] after connecting and
  /// exposes `isProtocolCompatible` for the UI to surface a mismatch banner.
  static const String protocolVersion = '1.0.0';

  /// Returns the protocol version from the connected runtime.
  ///
  /// No params required. Response: `{ "version": "1.0.0" }`.
  ///
  /// The DevTools UI calls this immediately after connecting. If the major
  /// version returned differs from [protocolVersion], the UI should display a
  /// compatibility warning instead of silently delivering garbled data.
  static const String getVersion = '$prefix.getVersion';

  /// Requests an immediate refetch for a given query key.
  ///
  /// Required param: `queryKey` (String).
  static const String refetch = '$prefix.refetch';

  /// Marks a query stale and triggers a background refetch.
  ///
  /// Required param: `queryKey` (String).
  static const String invalidate = '$prefix.invalidate';

  /// Rolls back an in-progress optimistic update for a given query key.
  ///
  /// Required param: `queryKey` (String).
  static const String rollbackOptimistic = '$prefix.rollbackOptimistic';

  /// Returns a full [CacheSnapshot] — all active queries and mutations.
  ///
  /// No params required. Response may be large; consider pagination in future.
  static const String getCacheSnapshot = '$prefix.getCacheSnapshot';

  /// Returns one base64-encoded chunk from a previously stored lazy payload.
  ///
  /// Required params: `payloadId` (String), `chunkIndex` (int ≥ 0).
  static const String getPayloadChunk = '$prefix.getPayloadChunk';

  /// Legacy alias for [getPayloadChunk] kept for backward compatibility.
  ///
  /// Older DevTools UI builds may still dispatch this name. The runtime
  /// registers both and routes them to the same handler.
  static const String getPayload = '$prefix.getPayload';
}

/// Known extension event stream keys emitted by the runtime bridge.
///
/// The DevTools UI subscribes to the `"Extension"` VM service stream and
/// filters events by [qoraEvent] to receive Qora-specific payloads.
abstract final class QoraExtensionEvents {
  /// Primary stream kind for all Qora protocol events.
  ///
  /// Both sides must agree on this string. If it ever needs to change,
  /// keep the old value active as a fallback for at least one minor version.
  static const String qoraEvent = 'qora:event';
}
