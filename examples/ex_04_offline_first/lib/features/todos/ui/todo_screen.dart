import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import '../data/todo_api.dart';
import '../data/todo_mutations.dart';
import '../data/todo_view.dart';
import '../models/todo.dart';
import 'todo_tile.dart';

/// The todo list, with the queued writes laid over it.
///
/// - [QoraBuilder] reads the server's list; [FetchStatus.paused] tells
///   "offline" apart from "loading".
/// - A [MutationQueueBuilder] on `client.mutationQueue` overlays the writes
///   not confirmed yet, in this session or restored after a restart.
/// - Writes are registered mutations (`todos.create`, `todos.toggle`,
///   `todos.delete`) called with `offlineQueue: true`: no mutator here.
class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key, required this.api});

  final TodoApi api;

  @override
  Widget build(BuildContext context) {
    return QoraBuilder<List<Todo>>(
      queryKey: todosKey,
      fetcher: api.getTodos,
      builder: (context, state, fetchStatus) {
        // A fetch started offline with nothing cached pauses with
        // Loading(previousData: null): a spinner would spin until reconnect.
        if (state.dataOrNull == null && fetchStatus == FetchStatus.paused) {
          return const _OfflineEmptyState();
        }

        return switch (state) {
          Initial() || Loading(previousData: null) => const Center(
            child: CircularProgressIndicator(),
          ),
          Failure(:final error, previousData: null) => _ErrorView(error),
          _ => MutationQueueBuilder(
            builder: (context, entries, _) => _TodoList(
              todos: applyQueue(state.dataOrNull ?? const [], entries),
              isRefreshing: fetchStatus == FetchStatus.fetching,
              isOffline: fetchStatus == FetchStatus.paused,
            ),
          ),
        };
      },
    );
  }
}

class _TodoList extends StatelessWidget {
  const _TodoList({
    required this.todos,
    required this.isRefreshing,
    required this.isOffline,
  });

  final List<TodoView> todos;
  final bool isRefreshing;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (isRefreshing) const LinearProgressIndicator(minHeight: 2),
          if (isOffline) const _CachedDataHint(),
          Expanded(
            child: todos.isEmpty
                ? const Center(child: Text('No todos yet, add one below!'))
                : ListView.separated(
                    itemCount: todos.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _TodoRow(
                      key: ValueKey(todos[index].todo.id),
                      view: todos[index],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: const _AddTodoButton(),
    );
  }
}

/// One row, wired to the registered toggle and delete mutations.
///
/// The builders only provide `mutate`: what the row shows comes from the
/// queue, which also covers calls made before a restart.
class _TodoRow extends StatelessWidget {
  const _TodoRow({super.key, required this.view});

  final TodoView view;

  @override
  Widget build(BuildContext context) {
    final todo = view.todo;
    return QoraMutationBuilder<Todo, ToggleTodoInput, void>(
      options: const MutationOptions(
        mutationKey: 'todos.toggle',
        offlineQueue: true,
      ),
      builder: (context, _, toggle) =>
          QoraMutationBuilder<void, DeleteTodoInput, void>(
            options: const MutationOptions(
              mutationKey: 'todos.delete',
              offlineQueue: true,
            ),
            builder: (context, _, delete) => TodoTile(
              view: view,
              onToggle: () => toggle(
                ToggleTodoInput(id: todo.id, completed: !todo.completed),
              ),
              onDelete: () => delete(DeleteTodoInput(id: todo.id)),
            ),
          ),
    );
  }
}

class _AddTodoButton extends StatelessWidget {
  const _AddTodoButton();

  @override
  Widget build(BuildContext context) {
    return QoraMutationBuilder<Todo, CreateTodoInput, void>(
      options: const MutationOptions(
        mutationKey: 'todos.create',
        offlineQueue: true,
      ),
      // Never disabled while a call is pending: offline, each new todo is
      // queued behind the others, and shows in the list at once.
      builder: (context, _, create) => FloatingActionButton.extended(
        onPressed: () async {
          final title = await _askTitle(context);
          if (title != null) await create(CreateTodoInput.newTodo(title));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Todo'),
      ),
    );
  }

  Future<String?> _askTitle(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Todo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Include "reject" to see a refused write',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final title = controller.text.trim();
    controller.dispose();
    return confirmed == true && title.isNotEmpty ? title : null;
  }
}

class _CachedDataHint extends StatelessWidget {
  const _CachedDataHint();

  @override
  Widget build(BuildContext context) {
    final color = Colors.orange.shade700;
    return ColoredBox(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 14, color: color),
            const SizedBox(width: 8),
            Text(
              'Showing cached data; changes will sync on reconnect',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineEmptyState extends StatelessWidget {
  const _OfflineEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No connection\nConnect to load your todos',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView(this.error);

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.qora.invalidate(todosKey),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
