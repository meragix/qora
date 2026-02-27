/// View entity for mutation inspector details.
class MutationDetail {
  /// Creates mutation detail model.
  const MutationDetail({
    required this.status,
    required this.retryCount,
    this.variables,
    this.error,
    this.rollbackContext,
  });

  /// Mutation status label.
  final String status;

  /// Number of retries.
  final int retryCount;

  /// Serialized variables.
  final Object? variables;

  /// Serialized error object.
  final Object? error;

  /// Rollback context object.
  final Object? rollbackContext;
}
