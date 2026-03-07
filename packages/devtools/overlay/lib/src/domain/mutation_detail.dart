import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// View-model for the Mutation Inspector panel (column 2).
///
/// Derived from a [MutationEvent] snapshot; exposes computed fields that
/// the inspector panel renders directly — status badge, raw data for the
/// JSON viewer, and metadata rows.
class MutationDetail {
  /// Human-readable mutation status: `'pending'`, `'success'`, or `'error'`.
  final String status;

  /// Raw variables passed to the mutation, or `null` if none.
  final dynamic variables;

  /// Raw error/result — only present when [status] is `'error'`.
  final dynamic error;

  /// Raw rollback context — only present for optimistic-update mutations.
  ///
  /// Currently `null`; will be populated when the tracker exposes rollback data.
  final dynamic rollbackContext;

  /// Timestamp of the `mutation.started` event.
  final DateTime createdAt;

  /// Timestamp when the mutation was submitted to the server (same as [createdAt] for now).
  final DateTime? submittedAt;

  /// Timestamp of the last state update (settle event), if any.
  final DateTime? updatedAt;

  /// Number of retry attempts for this mutation (not yet tracked; always 0).
  final int retryCount;

  const MutationDetail({
    required this.status,
    this.variables,
    this.error,
    this.rollbackContext,
    required this.createdAt,
    this.submittedAt,
    this.updatedAt,
    this.retryCount = 0,
  });

  /// Builds a [MutationDetail] from the latest [MutationEvent] snapshot.
  factory MutationDetail.fromEvent(MutationEvent event) {
    final isSettled = event.type == MutationEventType.settled;
    final isSuccess = isSettled && (event.success ?? false);
    final isError = isSettled && !(event.success ?? false);

    final status = isSuccess
        ? 'success'
        : isError
            ? 'error'
            : 'pending';

    return MutationDetail(
      status: status,
      variables: event.variables,
      error: isError ? event.result : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(event.timestampMs),
      updatedAt: isSettled
          ? DateTime.fromMillisecondsSinceEpoch(event.timestampMs)
          : null,
    );
  }
}
