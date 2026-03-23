import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// View-model for the Mutation Inspector panel (column 2).
///
/// Derived from a [MutationEvent] snapshot; exposes computed fields that
/// the inspector panel renders directly — status badge, raw data for the
/// JSON viewer, and metadata rows.
class MutationDetail {
  /// Runtime mutation identifier — stable across retries. Used as widget key
  /// for [JsonViewer] instances to force a full rebuild on selection change.
  final String id;

  /// The serialised mutation key, e.g. `["createPost"]` or `["updateUser", "42"]`.
  final String? key;

  /// Human-readable mutation status: `'pending'`, `'success'`, or `'error'`.
  final String status;

  /// Raw variables passed to the mutation, or `null` if none.
  final dynamic variables;

  /// Server response — only present when [status] is `'success'`.
  final dynamic data;

  /// Raw error/result — only present when [status] is `'error'`.
  final dynamic error;

  /// Raw rollback context — only present for optimistic-update mutations.
  ///
  /// Currently `null`; will be populated when the tracker exposes rollback data.
  final dynamic rollbackContext;

  /// Round-trip duration in milliseconds from `started` to `settled`.
  ///
  /// `null` while the mutation is still pending (no settle event yet).
  final int? elapsedMs;

  /// Timestamp of the `mutation.started` event.
  final DateTime createdAt;

  /// Timestamp when the mutation was submitted to the server (same as [createdAt] for now).
  final DateTime? submittedAt;

  /// Timestamp of the last state update (settle event), if any.
  final DateTime? updatedAt;

  /// Whether this mutation carries an optimistic update.
  ///
  /// `true` when [QoraClient.setQueryData] was called for the associated key
  /// before the server confirmed the result. In the overlay this is inferred
  /// by correlating [OverlayTracker.onOptimisticUpdate] with the mutation start;
  /// in the IDE extension it is read directly from the protocol JSON.
  final bool isOptimistic;

  /// Number of retry attempts for this mutation.
  ///
  /// In the overlay this stays `0` — the [QoraTracker] interface does not
  /// expose a per-retry hook for mutations. In the IDE extension it is
  /// populated from the protocol JSON field `retryCount`.
  final int retryCount;

  const MutationDetail({
    required this.id,
    this.key,
    required this.status,
    this.variables,
    this.data,
    this.error,
    this.rollbackContext,
    this.elapsedMs,
    required this.createdAt,
    this.submittedAt,
    this.updatedAt,
    this.isOptimistic = false,
    this.retryCount = 0,
  });

  /// Builds a [MutationDetail] from the latest [MutationEvent] snapshot.
  ///
  /// [startedAtMs] is the timestamp of the original `started` event, used to
  /// compute [elapsedMs]. Pass `null` when the start time is unavailable.
  factory MutationDetail.fromEvent(MutationEvent event, {int? startedAtMs}) {
    final isSettled = event.type == MutationEventType.settled;
    final isSuccess = isSettled && (event.success ?? false);
    final isError = isSettled && !(event.success ?? false);

    final status = isSuccess
        ? 'success'
        : isError
            ? 'error'
            : 'pending';

    final elapsedMs = (isSettled && startedAtMs != null)
        ? event.timestampMs - startedAtMs
        : null;

    return MutationDetail(
      id: event.id,
      key: event.key,
      status: status,
      variables: event.variables,
      data: isSuccess ? event.result : null,
      error: isError ? event.result : null,
      elapsedMs: elapsedMs,
      createdAt: (startedAtMs ?? event.timestampMs).toDateTime(),
      updatedAt: isSettled ? event.timestampMs.toDateTime() : null,
      isOptimistic: event.isOptimistic,
      retryCount: event.retryCount,
    );
  }
}
