import 'qora_command.dart';

/// Command requesting a query invalidation from the runtime.
final class InvalidateCommand extends QoraCommand {
  /// Target query key.
  final String queryKey;

  /// Creates an invalidation command for [queryKey].
  const InvalidateCommand({required this.queryKey});

  @override
  String get method => 'invalidate';

  @override
  Map<String, String> get params => <String, String>{'queryKey': queryKey};
}
