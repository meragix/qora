import 'dart:convert';
import 'dart:typed_data';

import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/data/vm_service_client.dart';
import 'package:qora_devtools_ui/src/domain/repositories/payload_repository.dart';

/// Default [PayloadRepository] implementation backed by [VmServiceClient].
///
/// Reconstructs large payloads by issuing sequential `GetPayloadChunkCommand`
/// calls for each chunk index, base64-decoding each response, concatenating
/// the bytes, and JSON-decoding the result.
///
/// ## Sequential vs. parallel chunk fetching
///
/// Chunks are fetched sequentially to avoid overwhelming the VM service with
/// concurrent extension calls. The Dart VM serialises extension calls in the
/// app isolate, so true parallelism would not help and could increase latency.
///
/// If perceived latency is an issue at high chunk counts, consider
/// pre-fetching the next chunk while processing the current one (pipelining)
/// in a future optimisation.
///
/// ## Error handling
///
/// Throws [StateError] when any chunk returns no `data` field (e.g. because
/// the payload has expired on the runtime side after the 30 s TTL). The
/// caller is responsible for surfacing this as a user-visible error and
/// offering a retry via [CacheController.refresh].
class PayloadRepositoryImpl implements PayloadRepository {
  final VmServiceClient _vmClient;

  /// Creates a payload repository backed by [vmClient].
  const PayloadRepositoryImpl({required VmServiceClient vmClient})
      : _vmClient = vmClient;

  @override
  Future<Object?> fetchPayload({
    required String payloadId,
    required int totalChunks,
  }) async {
    final chunks = <Uint8List>[];

    for (var i = 0; i < totalChunks; i++) {
      final response = await _vmClient.sendCommand(
        GetPayloadChunkCommand(payloadId: payloadId, chunkIndex: i),
      );

      final encoded = response['data'] as String?;
      if (encoded == null || encoded.isEmpty) {
        throw StateError('Missing payload chunk data for $payloadId#$i');
      }

      chunks.add(base64.decode(encoded));
    }

    final bytes = Uint8List.fromList(chunks.expand((chunk) => chunk).toList());
    return jsonDecode(utf8.decode(bytes));
  }
}
