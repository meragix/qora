/// Passed to `onError` when the app removes a queued call before it was
/// sent, with `MutationQueue.discard`, `discardScope` or `clear`.
///
/// The call site's `onError` receives it with the `onMutate` context, so the
/// rollback written for a rejected write also undoes an abandoned one.
final class MutationDiscardedException implements Exception {
  /// The `mutationId` of the discarded call.
  final String mutationId;

  /// The registered mutation key of the discarded call.
  final String key;

  /// Creates the error reported for a discarded call.
  const MutationDiscardedException({
    required this.mutationId,
    required this.key,
  });

  @override
  String toString() =>
      'MutationDiscardedException: $key ($mutationId) was discarded';
}
