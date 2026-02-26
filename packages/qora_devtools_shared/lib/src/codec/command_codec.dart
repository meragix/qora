import 'package:qora_devtools_shared/src/commands/get_cache_snapshot_command.dart';
import 'package:qora_devtools_shared/src/commands/get_playload_chunk_command.dart';
import 'package:qora_devtools_shared/src/commands/invalidate_command.dart';
import 'package:qora_devtools_shared/src/commands/qora_command.dart';
import 'package:qora_devtools_shared/src/commands/refetch_command.dart';
import 'package:qora_devtools_shared/src/commands/rollback_optimic_command.dart';
import 'package:qora_devtools_shared/src/protocol/extension_methods.dart';

/// JSON codec for Qora DevTools commands.
abstract final class CommandCodec {
  /// Encodes a command into a JSON-safe map.
  static Map<String, Object?> encode(QoraCommand command) => command.toJson();

  /// Decodes a command payload.
  ///
  /// The decoder accepts both forms:
  /// - method suffix (`refetch`)
  /// - full extension name (`ext.qora.refetch`)
  static QoraCommand decode(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Command payload must be a map');
    }

    final json = Map<String, Object?>.from(raw);
    final rawMethod = (json['method'] as String?) ?? '';
    final method = _normalizeMethod(rawMethod);
    final params = _extractParams(json['params']);

    switch (method) {
      case 'refetch':
        return RefetchCommand(queryKey: params['queryKey'] ?? '');
      case 'invalidate':
        return InvalidateCommand(queryKey: params['queryKey'] ?? '');
      case 'rollbackOptimistic':
        return RollbackOptimisticCommand(queryKey: params['queryKey'] ?? '');
      case 'getCacheSnapshot':
        return const GetCacheSnapshotCommand();
      case 'getPayloadChunk':
      case 'getPayload':
        return GetPayloadChunkCommand(
          payloadId: params['payloadId'] ?? '',
          chunkIndex: int.tryParse(params['chunkIndex'] ?? params['chunk'] ?? '0') ?? 0,
        );
      default:
        throw FormatException('Unsupported command method: $rawMethod');
    }
  }

  static String _normalizeMethod(String value) {
    if (value.startsWith('${QoraExtensionMethods.prefix}.')) {
      return value.substring('${QoraExtensionMethods.prefix}.'.length);
    }
    return value;
  }

  static Map<String, String> _extractParams(Object? raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }
    return raw.map<String, String>(
      (key, value) => MapEntry('$key', '$value'),
    );
  }
}
