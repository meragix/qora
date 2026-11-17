import 'package:meta/meta.dart';

/// Identity of one call to a registered mutation, passed to its mutator.
///
/// A registered mutation (see `QoraClient.registerMutation`) may run more
/// than once for a single call: its retries, and its replay when a call
/// queued offline is sent on reconnect. [mutationId] is the same for all of
/// them, so the server can recognise a write it already applied.
///
/// ```dart
/// client.registerMutation<Todo, NewTodo>(
///   'todos.create',
///   mutator: (input, meta) => api.createTodo(
///     input,
///     headers: {'Idempotency-Key': meta.mutationId},
///   ),
///   variables: newTodoSerializer,
/// );
/// ```
///
/// Delivery is at-least-once: if the app stops after the server applied a
/// write but before the response arrived, the write is sent again with the
/// same [mutationId]. Exactly-once delivery requires the server to
/// deduplicate on it.
@immutable
final class MutationMeta {
  /// Stable identifier of this call, shared by every attempt and replay.
  ///
  /// A random version 4 UUID, generated when the call is made.
  final String mutationId;

  /// Zero-based index of the attempt: `0` for the first try, `1` for the first
  /// retry, and so on.
  final int attempt;

  /// Creates the metadata for one attempt of a registered mutation.
  const MutationMeta({required this.mutationId, required this.attempt});

  @override
  bool operator ==(Object other) =>
      other is MutationMeta &&
      other.mutationId == mutationId &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(mutationId, attempt);

  @override
  String toString() =>
      'MutationMeta(mutationId: $mutationId, attempt: $attempt)';
}
