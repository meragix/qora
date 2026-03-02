import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_qora/flutter_qora.dart';

import 'use_query_client.dart';

/// Returns `true` when at least one mutation managed by the nearest
/// [QoraClient] is actively running (i.e. in [MutationPending] state).
///
/// Subscribes to [QoraClient.mutationEvents] and re-reads
/// [QoraClient.activeMutations] on every event to keep the count up-to-date.
/// Initialises synchronously from the current [QoraClient.activeMutations]
/// snapshot.
///
/// ```dart
/// class SaveButton extends HookWidget {
///   final VoidCallback onSave;
///   const SaveButton({super.key, required this.onSave});
///
///   @override
///   Widget build(BuildContext context) {
///     final isMutating = useIsMutating();
///     return FilledButton(
///       onPressed: isMutating ? null : onSave,
///       child: isMutating
///           ? const SizedBox.square(
///               dimension: 18,
///               child: CircularProgressIndicator(strokeWidth: 2),
///             )
///           : const Text('Save'),
///     );
///   }
/// }
/// ```
bool useIsMutating() {
  final client = useQueryClient();

  // Initialise from the synchronous snapshot.
  final count = useState(client.activeMutations.length);

  useEffect(() {
    final sub = client.mutationEvents.listen(
      (_) => count.value = client.activeMutations.length,
    );
    return sub.cancel;
  }, [client]);

  return count.value > 0;
}
