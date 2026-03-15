import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import '../data/todo_api.dart';
import '../models/todo.dart';
import 'todo_tile.dart';

/// Main screen: todo list + add button.
///
/// Key patterns demonstrated:
/// - [QoraBuilder] with [FetchStatus.paused] detection for the offline case.
/// - [QoraMutationBuilder] with [MutationOptions.offlineQueue] and
///   [MutationOptions.optimisticResponse] for create-todo.
/// - Inline [QoraMutationBuilder]s on each tile for toggle and delete.
class TodoScreen extends StatelessWidget {
  final TodoApi api;

  const TodoScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return QoraBuilder<List<Todo>>(
      queryKey: const ['todos'],
      fetcher: api.getTodos,
      builder: (context, state, fetchStatus) {
        // ── Offline + no cache at all ─────────────────────────────────────
        if (state is Initial && fetchStatus == FetchStatus.paused) {
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

        return switch (state) {
          // ── No data yet ─────────────────────────────────────────────────
          Initial() || Loading(previousData: null) => const Center(
            child: CircularProgressIndicator(),
          ),

          Failure(:final error, previousData: null) => Center(
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
                    onPressed: () => context.qora.invalidate(const ['todos']),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),

          // ── Data available (Success, or Loading/Failure with stale data) ─
          _ => _TodoList(
            todos: state.dataOrNull ?? [],
            isRefreshing: fetchStatus == FetchStatus.fetching,
            isOffline: fetchStatus == FetchStatus.paused,
            api: api,
          ),
        };
      },
    );
  }
}

// ── Private list + FAB ──────────────────────────────────────────────────────

class _TodoList extends StatelessWidget {
  final List<Todo> todos;
  final bool isRefreshing;
  final bool isOffline;
  final TodoApi api;

  const _TodoList({
    required this.todos,
    required this.isRefreshing,
    required this.isOffline,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // ── Stale-data revalidation indicator ─────────────────────────
            if (isRefreshing) const LinearProgressIndicator(minHeight: 2),

            // ── Offline + cached data hint ────────────────────────────────
            if (isOffline)
              ColoredBox(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 14,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Showing cached data · changes will sync on reconnect',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Todo list ─────────────────────────────────────────────────
            Expanded(
              child: todos.isEmpty
                  ? const Center(child: Text('No todos yet — add one below!'))
                  : ListView.separated(
                      itemCount: todos.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final todo = todos[index];
                        return _TodoTileWithMutations(todo: todo, api: api);
                      },
                    ),
            ),
          ],
        ),

        // ── FAB: add todo (with offline queue) ────────────────────────────
        Positioned(bottom: 16, right: 16, child: _AddTodoFab(api: api)),
      ],
    );
  }
}

// ── Tile wrapper with toggle + delete mutations ─────────────────────────────

class _TodoTileWithMutations extends StatelessWidget {
  final Todo todo;
  final TodoApi api;

  const _TodoTileWithMutations({required this.todo, required this.api});

  @override
  Widget build(BuildContext context) {
    return QoraMutationBuilder<Todo, ToggleTodoInput, void>(
      queryKey: const ['todos'],
      mutator: api.toggleTodo,
      options: MutationOptions(
        offlineQueue: true,
        optimisticResponse: (input) =>
            todo.copyWith(completed: input.completed, isPending: true),
        onSuccess: (_, _, _) async => context.qora.invalidate(const ['todos']),
      ),
      builder: (context, toggleState, toggle) {
        return QoraMutationBuilder<void, DeleteTodoInput, void>(
          queryKey: const ['todos'],
          mutator: api.deleteTodo,
          options: MutationOptions(
            offlineQueue: true,
            onSuccess: (_, _, _) async =>
                context.qora.invalidate(const ['todos']),
          ),
          builder: (context, deleteState, delete) {
            // If a toggle optimistic result exists use that, otherwise the
            // canonical todo from the query.
            final displayTodo =
                (toggleState is MutationSuccess<Todo, ToggleTodoInput> &&
                    toggleState.isOptimistic)
                ? toggleState.data
                : todo;

            return TodoTile(
              todo: displayTodo,
              onToggle: toggle,
              onDelete: delete,
            );
          },
        );
      },
    );
  }
}

// ── FAB: create todo with offline queue ─────────────────────────────────────

class _AddTodoFab extends StatelessWidget {
  final TodoApi api;

  const _AddTodoFab({required this.api});

  @override
  Widget build(BuildContext context) {
    return QoraMutationBuilder<Todo, CreateTodoInput, void>(
      queryKey: const ['todos'],
      mutator: api.createTodo,
      options: MutationOptions(
        offlineQueue: true,
        // Optimistic: the item appears in the list immediately with isPending=true.
        optimisticResponse: (input) => Todo(
          id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
          title: input.title,
          completed: false,
          isPending: true,
        ),
        // onSuccess only fires for REAL server success (isOptimistic: false).
        // Replace the temp entry by invalidating the query.
        onSuccess: (_, _, _) async => context.qora.invalidate(const ['todos']),
      ),
      builder: (context, state, mutate) {
        final isQueued =
            state is MutationSuccess<Todo, CreateTodoInput> &&
            state.isOptimistic;

        return FloatingActionButton.extended(
          onPressed: state.isPending
              ? null
              : () => _showAddDialog(context, mutate),
          icon: isQueued ? const Icon(Icons.schedule) : const Icon(Icons.add),
          label: Text(isQueued ? 'Queued — syncing soon' : 'Add Todo'),
        );
      },
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    Future<Todo?> Function(CreateTodoInput) mutate,
  ) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Todo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'What needs to be done?'),
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
    if (confirmed == true && title.isNotEmpty) {
      await mutate(CreateTodoInput(title: title));
    }
  }
}
