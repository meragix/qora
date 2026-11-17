import 'package:meta/meta.dart';

/// Where a [QueuedMutation] stands in the mutation queue.
enum QueuedMutationStatus {
  /// Waiting for its turn, for the network, or for its next retry.
  queued,

  /// Its request is in flight.
  sending,

  /// Waits for a decision from the app before anything else in its scope
  /// is sent: it failed for good at the head of the scope, or an entry
  /// before it in the scope was discarded. The entries behind it are [held]
  /// until the app retries or discards it.
  blocked,

  /// Behind a [blocked] entry in the same scope; not sent.
  held,

  /// Failed for good without a scope. It left the replay order, and stays
  /// in the queue until the app retries or discards it.
  failed,
}

/// One registered call in the mutation queue, as the app sees it.
///
/// Read the queue with `MutationQueue.entries`. Entries are snapshots: a
/// later change produces a new [QueuedMutation].
@immutable
final class QueuedMutation {
  /// Stable identity of this call, passed to the mutator as
  /// `MutationMeta.mutationId`. Shared by every attempt; replaced only by
  /// `MutationQueue.retry` with new variables.
  final String mutationId;

  /// The registered mutation key.
  final String key;

  /// The scope returned by the registration's `scope`, or `null` for the
  /// global lane.
  final String? scope;

  /// The variables of this call, as passed to `mutate`.
  final Object? variables;

  /// When the call was queued.
  final DateTime enqueuedAt;

  /// Number of attempts made since the call was queued or last retried by
  /// the app.
  final int attempts;

  /// The error of the last failed attempt, or `null` if none failed yet.
  ///
  /// For a call restored by `PersistQoraClient.hydrate()`, the error's
  /// `toString()`: errors are stored as text.
  final Object? lastError;

  /// Where this entry stands in the queue.
  final QueuedMutationStatus status;

  /// Creates a snapshot of a queued call.
  const QueuedMutation({
    required this.mutationId,
    required this.key,
    required this.scope,
    required this.variables,
    required this.enqueuedAt,
    required this.attempts,
    required this.lastError,
    required this.status,
  });

  @override
  String toString() => 'QueuedMutation($key, id: $mutationId, '
      'scope: $scope, status: ${status.name}, attempts: $attempts)';
}
