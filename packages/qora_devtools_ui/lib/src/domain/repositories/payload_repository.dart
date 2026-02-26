/// Domain repository specialized in lazy/chunked payload retrieval.
abstract interface class PayloadRepository {
  /// Fetches and reconstructs a payload identified by [payloadId].
  Future<Object?> fetchPayload({
    required String payloadId,
    required int totalChunks,
  });
}
