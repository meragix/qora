import 'package:qora_flutter/qora_flutter.dart';

import '../models/todo.dart';
import 'todo_api.dart';

const todosKey = ['todos'];

/// Registers every write of the app, once, before `hydrate()`.
///
/// A registered mutation is stored with its variables, so a call queued
/// offline survives a restart and is sent by the next session. That is why
/// each registration needs a `variables` serializer, and why the mutator is
/// declared here rather than at the call site: after a restart, the widget
/// that made the call no longer exists, but this mutator does.
void registerTodoMutations(QoraClient client, TodoApi api) {
  // Every write to one todo shares its scope: a toggle queued after an
  // offline create waits for it, and is held if the server rejects it.
  String scope(String id) => 'todo:$id';
  bool isPermanent(Object error) =>
      error is ApiException && error.isClientError;

  client
    ..registerMutation<Todo, CreateTodoInput>(
      'todos.create',
      mutator: (input, meta) async {
        // meta.mutationId stays the same across retries and restarts: the
        // server uses it to apply this write once.
        final todo = await api.createTodo(
          input,
          idempotencyKey: meta.mutationId,
        );
        _patchList(
          client,
          (list) => [...list.where((t) => t.id != todo.id), todo],
        );
        return todo;
      },
      variables: QoraSerializer<CreateTodoInput>(
        toJson: (v) => v.toJson(),
        fromJson: (json) =>
            CreateTodoInput.fromJson(json as Map<String, dynamic>),
      ),
      scope: (input) => scope(input.id),
      isPermanent: isPermanent,
      invalidates: [todosKey],
    )
    ..registerMutation<Todo, ToggleTodoInput>(
      'todos.toggle',
      mutator: (input, meta) async {
        final todo = await api.toggleTodo(
          input,
          idempotencyKey: meta.mutationId,
        );
        _patchList(
          client,
          (list) => [for (final t in list) t.id == todo.id ? todo : t],
        );
        return todo;
      },
      variables: QoraSerializer<ToggleTodoInput>(
        toJson: (v) => v.toJson(),
        fromJson: (json) =>
            ToggleTodoInput.fromJson(json as Map<String, dynamic>),
      ),
      scope: (input) => scope(input.id),
      isPermanent: isPermanent,
      invalidates: [todosKey],
    )
    ..registerMutation<void, DeleteTodoInput>(
      'todos.delete',
      mutator: (input, meta) async {
        await api.deleteTodo(input, idempotencyKey: meta.mutationId);
        _patchList(client, (list) => [...list.where((t) => t.id != input.id)]);
      },
      variables: QoraSerializer<DeleteTodoInput>(
        toJson: (v) => v.toJson(),
        fromJson: (json) =>
            DeleteTodoInput.fromJson(json as Map<String, dynamic>),
      ),
      scope: (input) => scope(input.id),
      isPermanent: isPermanent,
      invalidates: [todosKey],
    );
}

/// Applies a confirmed write to the cached list right away.
///
/// The queue drops a call as soon as it succeeds, and the list shows pending
/// writes from the queue (see `todo_view.dart`). Without this patch, a todo
/// created offline would vanish until the refetch triggered by `invalidates`
/// completes.
void _patchList(QoraClient client, List<Todo> Function(List<Todo>) update) {
  final list = client.getQueryData<List<Todo>>(todosKey);
  if (list != null) client.setQueryData<List<Todo>>(todosKey, update(list));
}
