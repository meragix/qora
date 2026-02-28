/// Domain repository specialized in lazy/chunked payload retrieval.
///
/// [PayloadRepository] isolates the chunk-reassembly protocol behind a clean
/// interface.  It exists as a **separate** port from [EventRepository] to
/// honour the Single Responsibility Principle: [EventRepository] handles
/// event streaming and control commands; [PayloadRepository] handles
/// the multi-step process of reconstructing large binary payloads.
///
/// ## Lazy payload protocol recap
///
/// When a [QueryEvent] or [QuerySnapshot] carries data larger than the 80 KB
/// inline threshold, the runtime omits the data and instead emits:
/// - `payloadId` — an opaque handle registered in [PayloadStore]
/// - `totalChunks` — the number of 80 KB base64 chunks to fetch
///
/// [fetchPayload] issues [GetPayloadChunkCommand] once per chunk,
/// concatenates the decoded bytes, and returns the JSON-decoded result.
///
/// ## Implementation
///
/// - **Production**: [PayloadRepositoryImpl] — drives [VmServiceClient]
///   sequentially (one `callServiceExtension` call per chunk).
/// - **Tests**: a fake returning a canned `Object?` without network calls.
///
/// ## TTL constraint
///
/// All chunks must be fetched within **30 seconds** of the event being
/// emitted, after which [PayloadStore] evicts the entry.  Missing or empty
/// chunk data causes [fetchPayload] to throw [StateError].
abstract interface class PayloadRepository {
  /// Fetches and reconstructs the full JSON value identified by [payloadId].
  ///
  /// Issues [totalChunks] sequential [GetPayloadChunkCommand] calls,
  /// base64-decodes each response `data` field, concatenates the bytes, and
  /// returns `jsonDecode(utf8.decode(bytes))`.
  ///
  /// Throws [StateError] if any chunk returns empty or missing `data`
  /// (payload expired).
  Future<Object?> fetchPayload({
    required String payloadId,
    required int totalChunks,
  });
}
