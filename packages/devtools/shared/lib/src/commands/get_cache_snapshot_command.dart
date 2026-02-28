import 'qora_command.dart';

/// DevTools → runtime command that requests a point-in-time dump of the full
/// `QoraClient` cache.
///
/// ## Trigger
///
/// Sent by [CacheController.refresh] when the developer opens or manually
/// refreshes the **Cache Inspector** tab.  Delivered through
/// `callServiceExtension` on [QoraExtensionMethods.getCacheSnapshot]
/// (`ext.qora.getCacheSnapshot`).  No parameters are required.
///
/// ## Runtime behaviour
///
/// The extension handler iterates every active `QoraKey` in the
/// `QoraClient` cache and builds a [CacheSnapshot] response.
/// Large [QuerySnapshot.data] fields are omitted inline when they exceed the
/// 80 KB inline threshold; in that case [QuerySnapshot.payloadId] and
/// [QuerySnapshot.totalChunks] are set so the UI can pull chunks via
/// [GetPayloadChunkCommand].
///
/// ## On-demand vs. streaming
///
/// This command follows the **pull model** — the UI asks once and gets a
/// snapshot.  It does **not** establish a subscription; repeated calls are
/// needed to see subsequent cache mutations.  For live event streaming the
/// UI relies on the `qora:event` push stream instead.
///
/// ## Snapshot size
///
/// Response payload grows linearly with the number of active queries and
/// mutations.  For caches with hundreds of keys the runtime-side lazy chunking
/// keeps individual extension responses under the ~10 MB VM limit, but the
/// full logical snapshot may require many sequential
/// [GetPayloadChunkCommand] calls to reconstruct.
final class GetCacheSnapshotCommand extends QoraCommand {
  /// Creates a cache snapshot command (no parameters required).
  const GetCacheSnapshotCommand();

  @override
  String get method => 'getCacheSnapshot';

  @override
  Map<String, String> get params => const <String, String>{};
}
