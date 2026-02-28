import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';

/// Domain use-case that reconstructs a large query payload from the runtime's
/// [PayloadStore] via the lazy chunking protocol.
///
/// ## When is this needed?
///
/// When a [QueryEvent] or [QuerySnapshot] carries `hasLargePayload=true` the
/// inline `data` field is `null` and the event instead provides:
/// - `payloadId` — opaque handle into [PayloadStore]
/// - `totalChunks` — how many 80 KB chunks to fetch
///
/// [FetchLargePayloadUseCase] orchestrates the multi-step retrieval and
/// returns the fully decoded JSON value.
///
/// ## End-to-end flow
///
/// ```
/// FetchLargePayloadUseCase.call(payloadId: 'abc', totalChunks: 3)
///   → EventRepository.fetchFullPayload('abc', 3)
///   → PayloadRepository.fetchPayload(payloadId: 'abc', totalChunks: 3)
///   → GetPayloadChunkCommand × 3   [sequential ext calls]
///   → base64 decode → concatenate → utf8 decode → jsonDecode → Object?
/// ```
///
/// ## Error handling
///
/// Throws [StateError] (propagated from [PayloadRepositoryImpl]) if any chunk
/// is missing or the 30 s TTL has expired.  The caller should offer a retry
/// via [CacheController.refresh] or display an error banner.
///
/// ## Testability
///
/// Inject a fake [EventRepository] whose `fetchFullPayload` returns a
/// canned value:
///
/// ```dart
/// class FakeRepo implements EventRepository {
///   @override
///   Future<Object?> fetchFullPayload(_, __) async => {'key': 'value'};
///   // …other members
/// }
/// ```
class FetchLargePayloadUseCase {
  /// Creates the use-case backed by [_repository].
  const FetchLargePayloadUseCase(this._repository);

  final EventRepository _repository;

  /// Fetches and JSON-decodes the full payload identified by [payloadId].
  ///
  /// [totalChunks] must match the value emitted in the originating event or
  /// snapshot.  Throws [StateError] on TTL expiry or missing chunk data.
  Future<Object?> call({
    required String payloadId,
    required int totalChunks,
  }) {
    return _repository.fetchFullPayload(payloadId, totalChunks);
  }
}
