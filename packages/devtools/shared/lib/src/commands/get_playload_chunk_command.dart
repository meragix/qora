import 'qora_command.dart';

/// DevTools → runtime command that pulls a single 80 KB base64 chunk of a
/// large payload from [PayloadStore].
///
/// ## When is this command needed?
///
/// When a [QueryEvent] or [QuerySnapshot] carries data larger than the 80 KB
/// inline threshold, the runtime omits the raw data and instead sets:
/// - `payloadId` — opaque handle registered in [PayloadStore]
/// - `totalChunks` — how many sequential [GetPayloadChunkCommand] calls are
///   needed to reconstruct the full value
///
/// [PayloadRepositoryImpl] issues these commands sequentially (one per chunk
/// index) and reassembles the original JSON value from the concatenated bytes.
///
/// ## Full retrieval sequence
///
/// ```
/// // 1. Event arrives with hasLargePayload=true
/// QueryEvent event; // payloadId='abc', totalChunks=3
///
/// // 2. UI fetches each chunk
/// for (var i = 0; i < event.totalChunks!; i++) {
///   final chunk = await vmClient.sendCommand(
///     GetPayloadChunkCommand(payloadId: event.payloadId!, chunkIndex: i),
///   );
///   // chunk['data'] is a base64-encoded Uint8List segment
/// }
///
/// // 3. Concatenate decoded bytes → UTF-8 decode → jsonDecode
/// ```
///
/// ## TTL & expiry
///
/// Payload entries in [PayloadStore] expire after **30 seconds**.  If the
/// DevTools UI takes longer than 30 s to start fetching (e.g. the tab was
/// backgrounded), the runtime returns an empty `data` field.
/// [PayloadRepositoryImpl] treats this as a [StateError] and surfaces a
/// retry prompt via [CacheController.refresh].
///
/// ## Chunk ordering
///
/// Chunks **must** be requested in order (`chunkIndex` 0 … `totalChunks − 1`).
/// There is no partial-read or random-access protocol; the full sequence is
/// always required to reconstruct the value.
///
/// > **Note:** The filename (`get_playload_chunk_command.dart`) contains a
/// > historical typo; the class name is spelled correctly.
final class GetPayloadChunkCommand extends QoraCommand {
  /// Opaque handle previously emitted in a [QueryEvent] or [QuerySnapshot].
  ///
  /// Must be passed verbatim; the runtime uses this to look up the correct
  /// [PayloadStore] entry.  Returns an empty `data` field if the entry has
  /// expired (30 s TTL).
  final String payloadId;

  /// Zero-based sequential index of the chunk to retrieve.
  ///
  /// Valid range: `0 ≤ chunkIndex < totalChunks`.  Out-of-range indices
  /// return an empty `data` field from the runtime handler.
  final int chunkIndex;

  /// Creates a payload-chunk command for the given [payloadId] and
  /// [chunkIndex].
  const GetPayloadChunkCommand({
    required this.payloadId,
    required this.chunkIndex,
  });

  @override
  String get method => 'getPayloadChunk';

  @override
  Map<String, String> get params => <String, String>{
        'payloadId': payloadId,
        'chunkIndex': '$chunkIndex',
      };
}
