import 'qora_command.dart';

/// Command used to rollback an optimistic update for a given query key.
final class RollbackOptimisticCommand extends QoraCommand {
  /// Target query key.
  final String queryKey;

  /// Creates a rollback command.
  const RollbackOptimisticCommand({required this.queryKey});

  @override
  String get method => 'rollbackOptimistic';

  @override
  Map<String, String> get params => <String, String>{'queryKey': queryKey};
}
