import 'pending_mutation.dart';

/// Result of an [OfflineMutationQueue.replay] call.
class OfflineReplayResult {
  /// Number of mutations that executed and succeeded.
  final int succeeded;

  /// Number of mutations that executed and failed.
  final int failed;

  /// Mutations that failed during replay.
  ///
  /// When [OfflineMutationQueue.stopOnFirstError] is `true`, only the first
  /// failed mutation appears here; the rest are in [skipped].
  final List<PendingMutation> failedMutations;

  /// Mutations that were not replayed because a prior mutation failed and
  /// [OfflineMutationQueue.stopOnFirstError] is `true`.
  ///
  /// They remain in the queue and will be retried on the next [replay] call.
  final List<PendingMutation> skipped;

  const OfflineReplayResult({
    required this.succeeded,
    required this.failed,
    required this.failedMutations,
    required this.skipped,
  });

  /// `true` when at least one mutation failed.
  bool get hasFailures => failed > 0;

  /// `true` when all mutations succeeded.
  bool get allSucceeded => failed == 0 && skipped.isEmpty;

  @override
  String toString() =>
      'OfflineReplayResult(succeeded: $succeeded, failed: $failed, '
      'skipped: ${skipped.length})';
}

/// A FIFO queue of [PendingMutation]s accumulated while the device is offline.
///
/// Mutations are enqueued by [MutationController] when
/// [MutationOptions.offlineQueue] is `true` and the client is offline. They
/// are replayed in order by [QoraClient] when the device reconnects.
///
/// ## Design notes
///
/// - **In-memory only** for v0.6.0. A [StorageAdapter?] slot is reserved for
///   a future persistence extension without requiring a breaking API change.
/// - **FIFO order** is preserved. Avoid chaining dependent mutations (e.g.
///   "create post A then add comment to A") unless you set
///   [stopOnFirstError] to `false` and your mutators are idempotent.
/// - **DevTools-friendly**: [snapshot] exposes the pending queue as an
///   unmodifiable list, ideal for showing a "sync pending" badge.
///
/// ## Handling failures
///
/// When [stopOnFirstError] is `true` (default) and a mutation fails during
/// [replay]:
/// 1. The failed mutation is re-enqueued at the front.
/// 2. All subsequent mutations that were skipped remain in the queue.
/// 3. [OfflineReplayResult.failedMutations] and [.skipped] describe what
///    happened so the UI can surface a recovery action.
class OfflineMutationQueue {
  /// When `true` (default), replay stops at the first failed mutation.
  ///
  /// The failed mutation and all subsequent ones stay in the queue. Set to
  /// `false` to continue past failures — only safe when mutations are
  /// independent and idempotent.
  final bool stopOnFirstError;

  final List<PendingMutation> _queue = [];

  // StorageAdapter slot — reserved for v0.7+ persistence.
  // ignore: unused_field
  final Object? _storage;

  OfflineMutationQueue({this.stopOnFirstError = true}) : _storage = null;

  /// Number of mutations currently waiting to be replayed.
  int get length => _queue.length;

  /// `true` when no mutations are waiting.
  bool get isEmpty => _queue.isEmpty;

  /// An unmodifiable snapshot of the pending queue in FIFO order.
  ///
  /// Use this for DevTools — e.g. display a badge with `queue.length` and
  /// a list of pending operations.
  List<PendingMutation> get snapshot => List.unmodifiable(_queue);

  /// Appends [mutation] to the end of the queue.
  void enqueue(PendingMutation mutation) => _queue.add(mutation);

  /// Removes the mutation identified by [mutatorId] from the queue.
  ///
  /// No-op if no matching entry is found.
  void remove(String mutatorId) =>
      _queue.removeWhere((m) => m.mutatorId == mutatorId);

  /// Empties the queue without replaying any mutations.
  void clear() => _queue.clear();

  /// Replays all queued mutations in FIFO order.
  ///
  /// Each mutation is executed via its [PendingMutation.replay] closure, which
  /// calls the original [MutationController.mutate] with the original
  /// variables. State transitions (success/failure) are emitted on the
  /// controller's stream as normal.
  ///
  /// Returns an [OfflineReplayResult] describing the outcome.
  Future<OfflineReplayResult> replay() async {
    if (_queue.isEmpty) {
      return const OfflineReplayResult(
        succeeded: 0,
        failed: 0,
        failedMutations: [],
        skipped: [],
      );
    }

    var succeeded = 0;
    var failed = 0;
    final failedMutations = <PendingMutation>[];
    final skipped = <PendingMutation>[];

    // Snapshot to iterate — we will re-enqueue leftovers as needed.
    final toReplay = List<PendingMutation>.from(_queue);
    _queue.clear();

    for (final mutation in toReplay) {
      if (failed > 0 && stopOnFirstError) {
        skipped.add(mutation);
        continue;
      }

      try {
        await mutation.replay();
        succeeded++;
      } catch (_) {
        failed++;
        failedMutations.add(mutation);
      }
    }

    // Re-enqueue anything that did not run so it survives the next reconnect.
    if (stopOnFirstError && failedMutations.isNotEmpty) {
      _queue.addAll(failedMutations);
    }
    if (skipped.isNotEmpty) {
      _queue.addAll(skipped);
    }

    return OfflineReplayResult(
      succeeded: succeeded,
      failed: failed,
      failedMutations: List.unmodifiable(failedMutations),
      skipped: List.unmodifiable(skipped),
    );
  }
}
