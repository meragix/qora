import 'package:qora_flutter/qora_flutter.dart';

import '../models/todo.dart';

/// Where a todo stands relative to the server.
enum SyncState {
  /// The server has every change.
  synced,

  /// Changes are queued or being sent.
  pending,

  /// A change was rejected, or waits behind one: the user must decide.
  needsAttention,
}

/// A todo as the user should see it: the server's version plus the writes
/// still in the queue.
class TodoView {
  const TodoView(this.todo, this.sync);

  final Todo todo;
  final SyncState sync;
}

/// Overlays the queued writes on the server's list.
///
/// The pending state is read from `client.mutationQueue`, not written into the
/// query cache by `onMutate`: the queue is stored and restored, the cache's
/// optimistic writes are not. So a todo created offline still shows after a
/// restart, until the server confirms it.
List<TodoView> applyQueue(List<Todo> server, List<QueuedMutation> queue) {
  final todos = {for (final t in server) t.id: t};
  final sync = <String, SyncState>{};

  void mark(String id, QueuedMutationStatus status) {
    final next = switch (status) {
      QueuedMutationStatus.blocked ||
      QueuedMutationStatus.held ||
      QueuedMutationStatus.failed => SyncState.needsAttention,
      QueuedMutationStatus.queued ||
      QueuedMutationStatus.sending => SyncState.pending,
    };
    if (sync[id] != SyncState.needsAttention) sync[id] = next;
  }

  for (final entry in queue) {
    switch (entry.variables) {
      case CreateTodoInput(:final id, :final title):
        todos[id] ??= Todo(id: id, title: title, completed: false);
        mark(id, entry.status);
      case ToggleTodoInput(:final id, :final completed):
        final todo = todos[id];
        if (todo != null) todos[id] = todo.copyWith(completed: completed);
        mark(id, entry.status);
      case DeleteTodoInput(:final id):
        mark(id, entry.status);
        // A delete on its way hides the todo; a refused one leaves it shown,
        // flagged, so the user can see what did not go through.
        if (sync[id] == SyncState.pending) todos.remove(id);
    }
  }

  return [
    for (final todo in todos.values)
      TodoView(todo, sync[todo.id] ?? SyncState.synced),
  ];
}
