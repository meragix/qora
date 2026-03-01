import 'package:meta/meta.dart';

/// A mutation enqueued while the device was offline.
///
/// Created by [MutationController] when [MutationOptions.offlineQueue] is
/// `true` and the client reports [NetworkStatus.offline]. Replayed in FIFO
/// order by [OfflineMutationQueue] when the device reconnects.
///
/// The [replay] closure captures the original [MutationController.mutate]
/// call including typed variables — the type is erased at queue level but
/// fully preserved inside the closure.
@immutable
class PendingMutation {
  /// Unique identifier — mirrors [MutationController.id].
  ///
  /// Format: `mutation_N`.
  final String mutatorId;

  /// Type-erased variables passed to the original mutate call.
  ///
  /// Stored for DevTools observability and debugging. The [replay] closure
  /// retains the fully-typed variables internally.
  final Object? variables;

  /// When this mutation was enqueued.
  final DateTime enqueuedAt;

  /// Replays the mutation by invoking [MutationController.mutate] with the
  /// original variables.
  ///
  /// The returned [Future] resolves when the mutation settles (success or
  /// failure). Errors are captured in the controller's [MutationState] and
  /// do not propagate to the caller — call [OfflineMutationQueue.replay] and
  /// check [OfflineReplayResult] instead.
  final Future<void> Function() replay;

  const PendingMutation({
    required this.mutatorId,
    required this.variables,
    required this.enqueuedAt,
    required this.replay,
  });

  @override
  String toString() =>
      'PendingMutation(id: $mutatorId, enqueuedAt: $enqueuedAt)';
}
