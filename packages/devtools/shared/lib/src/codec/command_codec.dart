import 'package:qora_devtools_shared/src/commands/get_cache_snapshot_command.dart';
import 'package:qora_devtools_shared/src/commands/get_playload_chunk_command.dart';
import 'package:qora_devtools_shared/src/commands/invalidate_command.dart';
import 'package:qora_devtools_shared/src/commands/qora_command.dart';
import 'package:qora_devtools_shared/src/commands/refetch_command.dart';
import 'package:qora_devtools_shared/src/commands/rollback_optimic_command.dart';
import 'package:qora_devtools_shared/src/protocol/extension_methods.dart';

/// JSON codec for Qora DevTools commands.
///
/// Commands flow in the reverse direction from events: **DevTools UI → App**.
/// They are dispatched via `VmServiceClient.sendCommand` and arrive at
/// `ExtensionHandlers` in the runtime bridge.
///
/// ## Routing table
///
/// | Method suffix           | Command class               |
/// |-------------------------|-----------------------------|
/// | `refetch`               | [RefetchCommand]            |
/// | `invalidate`            | [InvalidateCommand]         |
/// | `rollbackOptimistic`    | [RollbackOptimisticCommand] |
/// | `getCacheSnapshot`      | [GetCacheSnapshotCommand]   |
/// | `getPayloadChunk`       | [GetPayloadChunkCommand]    |
/// | `getPayload` *(legacy)* | [GetPayloadChunkCommand]    |
///
/// ## Adding a new command
///
/// 1. Create the command class in `commands/<name>_command.dart`.
/// 2. Add its method suffix constant to [QoraExtensionMethods].
/// 3. Add a `case '<method>':` branch here in [decode].
/// 4. Register the handler in `ExtensionRegistrar.registerAll()`.
/// 5. Add a `handle<Name>` method to `ExtensionHandlers`.
abstract final class CommandCodec {
  /// Encodes a command into a JSON-safe map.
  ///
  /// The resulting map is not used for transport (VM service takes typed params
  /// directly); it is intended for logging, snapshots, and testing.
  static Map<String, Object?> encode(QoraCommand command) => command.toJson();

  /// Decodes a command payload produced by [encode] or built manually.
  ///
  /// The decoder accepts both forms for the `method` field:
  /// - method suffix only: `refetch`
  /// - full extension name: `ext.qora.refetch`
  ///
  /// Throws [FormatException] when [raw] is not a `Map` or the method is
  /// unrecognised.
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
