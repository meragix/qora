import 'qora_command.dart';

/// Command used to pull one chunk of a large payload.
final class GetPayloadChunkCommand extends QoraCommand {
  /// Opaque payload id previously emitted in an event.
  final String payloadId;

  /// Zero-based index of the desired chunk.
  final int chunkIndex;

  /// Creates a payload-chunk command.
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
