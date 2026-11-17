import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_flutter/qora_flutter.dart';

import 'use_query_client.dart';

/// Returns the calls in the nearest [QoraClient]'s [MutationQueue], and
/// rebuilds when they change: a call queued, sent, retried, failed,
/// discarded or done.
///
/// The queue holds the registered mutations called with
/// `MutationOptions(offlineQueue: true)`, online or not, and, with
/// `PersistQoraClient`, the calls restored by `hydrate()` after a restart.
/// Derive what the screen needs from the list:
///
/// ```dart
/// class SyncBadge extends HookWidget {
///   const SyncBadge({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final queue = useMutationQueue();
///     final needsAction = queue.where(
///       (e) =>
///           e.status == QueuedMutationStatus.blocked ||
///           e.status == QueuedMutationStatus.failed,
///     );
///     if (needsAction.isNotEmpty) {
///       return Text('${needsAction.length} change(s) need your attention');
///     }
///     if (queue.isNotEmpty) return Text('${queue.length} change(s) to sync');
///     return const SizedBox.shrink();
///   }
/// }
/// ```
///
/// Decide on a `blocked` or `failed` call with [MutationQueue.retry] or
/// [MutationQueue.discard], through `useQueryClient().mutationQueue`.
List<QueuedMutation> useMutationQueue() {
  final queue = useQueryClient().mutationQueue;
  final snapshot = useStream(
    queue.entriesStream,
    initialData: queue.entries,
    // Another client: start from its entries, not the previous client's.
    preserveState: false,
  );
  return snapshot.data ?? queue.entries;
}
