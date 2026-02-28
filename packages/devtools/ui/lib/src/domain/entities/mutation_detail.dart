/// Presentation model for the Mutation Inspector detail panel.
///
/// [MutationDetail] is a **read-only view entity** derived from a
/// [MutationEvent] when a developer taps a mutation row in the Mutations tab.
/// It aggregates all relevant fields for display in one place, so the UI
/// widget has zero protocol knowledge.
///
/// ## Derivation from [MutationEvent]
///
/// ```dart
/// MutationDetail.fromEvent(MutationEvent event) = MutationDetail(
///   status:          event.status,
///   retryCount:      event.retryCount,
///   variables:       event.variables,
///   error:           event.error,
///   rollbackContext: event.rollbackContext,
/// )
/// ```
///
/// ## Optimistic update context
///
/// When [rollbackContext] is non-null the mutation was applied optimistically.
/// The UI should surface a **"Rollback"** action that dispatches
/// [RollbackOptimisticCommand] via [RefetchQueryUseCase] (or a dedicated
/// rollback use-case) to restore the pre-optimistic snapshot in the runtime.
///
/// ## Nullability semantics
///
/// - [variables] is `null` for mutations that take no arguments.
/// - [error] is `null` while the mutation is in-flight or succeeded.
/// - [rollbackContext] is `null` when no optimistic update was applied.
class MutationDetail {
  /// Creates a mutation detail model from pre-extracted display data.
  const MutationDetail({
    required this.status,
    required this.retryCount,
    this.variables,
    this.error,
    this.rollbackContext,
  });

  /// Current lifecycle status label (e.g. `'started'`, `'settled'`).
  ///
  /// Matches the `status` field from the originating [MutationEvent].
  final String status;

  /// Number of automatic retries attempted so far.
  ///
  /// `0` means the mutation succeeded or failed on the first attempt.
  final int retryCount;

  /// JSON-serialised mutation input variables, or `null` if not applicable.
  ///
  /// Displayed as a formatted JSON tree in the inspector panel.
  final Object? variables;

  /// JSON-serialised error object from the last failure, or `null` if the
  /// mutation has not yet failed.
  ///
  /// May be a `String`, `Map`, or any JSON-compatible type.
  final Object? error;

  /// Snapshot of the pre-optimistic cache state, or `null` if no optimistic
  /// update was applied.
  ///
  /// Non-null value indicates the DevTools UI should offer a rollback action
  /// via [RollbackOptimisticCommand].
  final Object? rollbackContext;
}
