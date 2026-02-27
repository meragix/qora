import 'qora_command.dart';

/// Command used to fetch a full cache snapshot from the runtime.
final class GetCacheSnapshotCommand extends QoraCommand {
  /// Creates a cache snapshot command.
  const GetCacheSnapshotCommand();

  @override
  String get method => 'getCacheSnapshot';

  @override
  Map<String, String> get params => const <String, String>{};
}
