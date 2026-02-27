import 'dart:convert';
import 'dart:typed_data';

import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/data/vm_service_client.dart';
import 'package:qora_devtools_ui/src/domain/repositories/payload_repository.dart';

/// Default implementation of [PayloadRepository] backed by [VmServiceClient].
class PayloadRepositoryImpl implements PayloadRepository {
  final VmServiceClient _vmClient;

  /// Creates a payload repository.
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
