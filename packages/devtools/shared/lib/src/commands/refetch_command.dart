import 'qora_command.dart';

/// Command requesting a query refetch from the runtime.
final class RefetchCommand extends QoraCommand {
  /// Target query key.
  final String queryKey;

  /// Creates a refetch command for [queryKey].
  const RefetchCommand({required this.queryKey});

  @override
  String get method => 'refetch';

  @override
  Map<String, String> get params => <String, String>{'queryKey': queryKey};
}
