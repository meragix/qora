import 'qora_command.dart';

/// DevTools → runtime command that rolls back an in-flight optimistic update
/// for a given query key.
///
/// ## Context — optimistic updates in Qora
///
/// `QoraClient.setQueryData<T>()` lets mutation code apply an **optimistic**
/// (speculative) state to the cache before the server confirms the change.
/// `QoraClient.restoreQueryData<T>()` reverts it on failure.
///
/// Normally rollback is automatic when the owning mutation's `onError` fires.
/// This command gives the DevTools operator an **emergency escape hatch**:
/// force-restore the pre-optimistic snapshot without waiting for the mutation
/// to settle (useful during debugging or when a mutation is stuck).
///
/// ## Trigger
///
/// Sent by the DevTools UI when the developer taps the **"Rollback"** action
/// in the mutation inspector or query detail panel.  Delivered through
/// `callServiceExtension` on [QoraExtensionMethods.rollbackOptimistic]
/// (`ext.qora.rollbackOptimistic`).
///
/// ## Runtime behaviour
///
/// The extension handler calls `QoraClient.restoreQueryData(key)`.  If no
/// optimistic snapshot exists for [queryKey] the call is a safe no-op.
/// The reverted state change pushes a `QueryEvent` back to the DevTools UI
/// via the normal event stream.
///
/// ## Key serialisation
///
/// [queryKey] must be the **string-serialised** form of the `QoraKey`.
/// See [RefetchCommand.queryKey] for details.
///
/// > **Note:** The filename (`rollback_optimic_command.dart`) contains a
/// > historical typo; the class name is spelled correctly.
final class RollbackOptimisticCommand extends QoraCommand {
  /// String-serialised `QoraKey` of the query whose optimistic snapshot
  /// should be restored.
  ///
  /// If [queryKey] has no pending optimistic state the runtime handler
  /// treats the call as a no-op.
  final String queryKey;

  /// Creates a rollback command targeting [queryKey].
  const RollbackOptimisticCommand({required this.queryKey});

  @override
  String get method => 'rollbackOptimistic';

  @override
  Map<String, String> get params => <String, String>{'queryKey': queryKey};
}
