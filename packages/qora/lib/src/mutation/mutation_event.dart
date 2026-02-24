import 'package:meta/meta.dart';
import 'package:qora/src/mutation/mutation_state_extensions.dart';

/// An event emitted by [QoraClient] whenever a tracked [MutationController]
/// changes state.
///
/// Observed via [QoraClient.mutationEvents].
///
/// Type parameters are erased at the event bus level — [data], [error], and
/// [variables] are typed as [Object?]. Use [mutatorId] to correlate with a
/// specific [MutationController] instance if full type information is needed.
///
/// ## DevTools pattern
///
/// ```dart
/// // On connect: read current snapshot first, then subscribe for updates.
/// final current = client.activeMutations;
/// client.mutationEvents.listen((event) {
///   if (event.isError) showToast('Mutation failed: ${event.error}');
/// });
/// ```
@immutable
class MutationEvent {
  /// Unique identifier of the [MutationController] that emitted this event.
  ///
  /// Format: `mutation_N` where N is a monotonically increasing counter.
  final String mutatorId;

  /// Coarse-grained status of the mutation at the time of this event.
  final MutationStatus status;

  /// The result data on success, or `null` for other states.
  final Object? data;

  /// The error on failure, or `null` for other states.
  final Object? error;

  /// The variables passed to the mutator, or `null` when [isIdle].
  final Object? variables;

  /// When this event was emitted.
  final DateTime timestamp;

  /// Arbitrary key-value pairs forwarded from [MutationController.metadata].
  ///
  /// Allows attaching domain context (e.g. `{'category': 'auth'}`) that flows
  /// through to the DevTools event bus without modifying the core event schema.
  /// `null` when the controller was created without [MutationController.metadata].
  final Map<String, Object?>? metadata;

  const MutationEvent({
    required this.mutatorId,
    required this.status,
    required this.timestamp,
    this.data,
    this.error,
    this.variables,
    this.metadata,
  });

  bool get isIdle => status == MutationStatus.idle;
  bool get isPending => status == MutationStatus.pending;
  bool get isSuccess => status == MutationStatus.success;
  bool get isError => status == MutationStatus.error;

  /// `true` when the mutation has completed — either successfully or with an
  /// error.
  ///
  /// The tracker uses this to automatically purge the entry from
  /// [QoraClient.activeMutations], ensuring the snapshot only contains
  /// **currently running** (pending) mutations and never accumulates
  /// "ghost" entries for completed ones.
  bool get isFinished => isSuccess || isError;

  @override
  String toString() =>
      'MutationEvent(id: $mutatorId, status: $status, at: $timestamp)';
}
