import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';

/// Domain use-case that reconstructs a large payload referenced by metadata.
class FetchLargePayloadUseCase {
  final EventRepository _repository;

  /// Creates the use-case.
  const FetchLargePayloadUseCase(this._repository);

  /// Fetches and decodes the full payload.
  Future<Object?> call({
    required String payloadId,
    required int totalChunks,
  }) {
    return _repository.fetchFullPayload(payloadId, totalChunks);
  }
}
