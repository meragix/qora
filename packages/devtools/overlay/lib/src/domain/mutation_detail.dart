import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// View-model for the Mutation Inspector panel (column 2).
///
/// Derived from a [MutationEvent] snapshot; exposes computed fields that
/// the inspector panel renders directly — status badge, variable preview,
/// error section, rollback context, and metadata rows.
class MutationDetail {
  /// Human-readable mutation status: `'pending'`, `'success'`, or `'error'`.
  final String status;

  /// Truncated string representation of the mutation variables, or `null` if none.
  final String? variablesPreview;

  /// Number of top-level variable entries (1 if variables is set, 0 otherwise).
  final int variablesCount;

  /// Truncated error description — only present when [status] is `'error'`.
  final String? errorPreview;

  /// Number of error entries — only present when [status] is `'error'`.
  final int? errorCount;

  /// Rollback context preview — only present for optimistic-update mutations.
  ///
  /// Currently `null`; will be populated when the tracker exposes rollback data.
  final String? rollbackContextPreview;

  /// Number of rollback context entries.
  final int? rollbackCount;

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
    this.variablesPreview,
    this.variablesCount = 0,
    this.errorPreview,
    this.errorCount,
    this.rollbackContextPreview,
    this.rollbackCount,
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
      variablesPreview: event.variables?.toString(),
      variablesCount: event.variables != null ? 1 : 0,
      errorPreview: isError ? event.result?.toString() : null,
      errorCount: isError ? 1 : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(event.timestampMs),
      updatedAt: isSettled
          ? DateTime.fromMillisecondsSinceEpoch(event.timestampMs)
          : null,
    );
  }
}
