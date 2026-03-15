import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/connectivity/simulated_connectivity_manager.dart';
import '../data/todo_api.dart';
import '../models/todo.dart';
import 'todo_tile.dart';

/// The main todo list screen.
///
/// Demonstrates all five production patterns side-by-side:
///
/// | Pattern                | Widget / API                              |
/// |------------------------|-------------------------------------------|
/// | Infinite scroll        | [InfiniteQueryBuilder] + sentinel item    |
/// | Pull-to-refresh        | [RefreshIndicator] + controller.refetch   |
/// | Optimistic create      | local `_pendingTodos` + [QoraMutationBuilder] offlineQueue |
/// | Toggle / delete        | [QoraMutationBuilder] per-tile + invalidate |
/// | Offline resilience     | [NetworkMode.offlineFirst] + FetchStatus  |
class TodoListScreen extends StatefulWidget {
  final TodoApi api;
  final AuthService authService;
  final SimulatedConnectivityManager connectivity;

  const TodoListScreen({
    super.key,
    required this.api,
    required this.authService,
    required this.connectivity,
  });

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  /// Optimistic todos shown at the top while a create mutation is queued.
  ///
  /// Populated in [onMutate] and cleared in [onSuccess] / [onError].
  final List<Todo> _pendingTodos = [];

  String get _userId => widget.authService.value!.id;
  Object get _queryKey => ['todos', _userId];

  MutationOptions<Todo, CreateTodoInput, List<Todo>> get _createOptions =>
      MutationOptions(
        offlineQueue: true,
        optimisticResponse: (input) =>
            Todo.optimistic(title: input.title, userId: input.userId),
        onMutate: (input) async {
          // Add optimistic entry immediately — visible before network response.
          final optimistic =
              Todo.optimistic(title: input.title, userId: input.userId);
          setState(() => _pendingTodos.add(optimistic));
          return [..._pendingTodos]; // snapshot for rollback
        },
        onSuccess: (_, _, _) async {
          setState(() => _pendingTodos.clear());
          context.qora.invalidate(_queryKey);
        },
        onError: (_, _, snapshot) async {
          // Rollback: restore the pending list to the snapshot taken in onMutate.
          if (snapshot != null) {
            setState(() {
              _pendingTodos
                ..clear()
                ..addAll(snapshot);
            });
          }
        },
      );

  @override
  Widget build(BuildContext context) {
    final isOffline = widget.connectivity.isOffline;

    return QoraMutationBuilder<Todo, CreateTodoInput, List<Todo>>(
      queryKey: _queryKey,
      mutator: widget.api.createTodo,
      options: _createOptions,
      builder: (context, createState, createTodo) {
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.authService.value!.name}\'s Todos'),
            actions: [
              // ── Connectivity toggle ─────────────────────────────────────
              Tooltip(
                message: isOffline ? 'Go online' : 'Simulate offline',
                child: IconButton(
                  icon: Icon(isOffline ? Icons.wifi_off : Icons.wifi),
                  color: isOffline ? Colors.amber.shade700 : null,
                  onPressed: () {
                    widget.connectivity.toggle();
                    setState(() {}); // refresh AppBar icon
                  },
                ),
              ),
              // ── Logout ──────────────────────────────────────────────────
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
                onPressed: () {
                  context.qora.invalidate(_queryKey);
                  widget.authService.logout();
                },
              ),
            ],
          ),
          body: InfiniteQueryBuilder<TodosPage, int>(
            queryKey: _queryKey,
            fetcher: (page) => widget.api.getTodosPage(_userId, page: page),
            options: InfiniteQueryOptions(
              initialPageParam: 1,
              getNextPageParam: (last, all) =>
                  last.hasMore ? all.length + 1 : null,
              baseOptions: const QoraOptions(
                staleTime: Duration(minutes: 5),
              ),
            ),
            builder: (context, state, controller) {
              // ── First load ───────────────────────────────────────────────
              if (state is InfiniteInitial || state is InfiniteLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              // ── Error with no data ───────────────────────────────────────
              if (state is InfiniteFailure<TodosPage, int> &&
                  state.previousData == null) {
                return _ErrorView(
                  error: state.error,
                  onRetry: () => context.qora.invalidate(_queryKey),
                );
              }

              // ── Success or failure with stale data ───────────────────────
              final successState =
                  state is InfiniteSuccess<TodosPage, int> ? state : null;
              final failureState =
                  state is InfiniteFailure<TodosPage, int> ? state : null;
              final data = successState?.data ?? failureState!.previousData!;

              return _buildList(
                context: context,
                todos: data.flatten((p) => p.todos),
                hasNextPage: successState?.hasNextPage ?? false,
                isFetchingNextPage:
                    successState?.isFetchingNextPage ?? false,
                controller: controller,
                errorBanner: failureState != null
                    ? '${failureState.error}'
                    : null,
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'New todo',
            onPressed: createState.isPending
                ? null
                : () => _showCreateDialog(context, createTodo),
            child: createState.isPending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildList({
    required BuildContext context,
    required List<Todo> todos,
    required bool hasNextPage,
    required bool isFetchingNextPage,
    required InfiniteQueryController<TodosPage, int> controller,
    String? errorBanner,
  }) {
    final allItems = [..._pendingTodos, ...todos];
    final itemCount = allItems.length + (hasNextPage ? 1 : 0);

    return RefreshIndicator(
      onRefresh: controller.refetch,
      child: Column(
        children: [
          // ── Background revalidation indicator ───────────────────────────
          if (isFetchingNextPage) const LinearProgressIndicator(minHeight: 2),

          // ── Error banner over stale data ────────────────────────────────
          if (errorBanner != null)
            _ErrorBanner(message: 'Refresh failed: $errorBanner'),

          Expanded(
            child: allItems.isEmpty && !hasNextPage
                ? const Center(child: Text('No todos yet — add one!'))
                : ListView.builder(
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      // ── Sentinel — triggers next page load ────────────
                      if (index == allItems.length) {
                        if (!isFetchingNextPage) controller.fetchNextPage();
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final todo = allItems[index];

                      // ── Optimistic (pending) todos ─────────────────────
                      if (todo.isOptimistic) {
                        return TodoTile(todo: todo);
                      }

                      // ── Real todos with toggle + delete mutations ──────
                      return _MutableTodoTile(
                        todo: todo,
                        api: widget.api,
                        queryKey: _queryKey,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(
    BuildContext context,
    Future<Todo?> Function(CreateTodoInput) createTodo,
  ) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('New Todo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'What needs to be done?',
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _submitCreate(dialogCtx, ctrl, createTodo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submitCreate(dialogCtx, ctrl, createTodo),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _submitCreate(
    BuildContext dialogCtx,
    TextEditingController ctrl,
    Future<Todo?> Function(CreateTodoInput) createTodo,
  ) {
    final title = ctrl.text.trim();
    if (title.isEmpty) return;
    Navigator.of(dialogCtx).pop();
    createTodo(CreateTodoInput(title: title, userId: _userId));
  }
}

// ── Per-tile mutations ────────────────────────────────────────────────────────

/// Wraps a [TodoTile] with toggle and delete [QoraMutationBuilder]s.
///
/// Each tile creates its own short-lived controllers so mutations are
/// independent — toggling item A doesn't block item B.
class _MutableTodoTile extends StatelessWidget {
  final Todo todo;
  final TodoApi api;
  final Object queryKey;

  const _MutableTodoTile({
    required this.todo,
    required this.api,
    required this.queryKey,
  });

  @override
  Widget build(BuildContext context) {
    return QoraMutationBuilder<Todo, ToggleTodoInput, void>(
      queryKey: queryKey,
      mutator: api.toggleTodo,
      options: MutationOptions(
        onSuccess: (_, _, _) async => context.qora.invalidate(queryKey),
      ),
      builder: (context, toggleState, toggle) {
        return QoraMutationBuilder<void, String, void>(
          queryKey: queryKey,
          mutator: api.deleteTodo,
          options: MutationOptions(
            onSuccess: (_, _, _) async => context.qora.invalidate(queryKey),
          ),
          builder: (context, deleteState, delete) {
            return TodoTile(
              todo: todo,
              onToggle: toggleState.isPending
                  ? null
                  : () => toggle(
                        ToggleTodoInput(
                          id: todo.id,
                          completed: !todo.completed,
                        ),
                      ),
              onDelete: deleteState.isPending ? null : () => delete(todo.id),
            );
          },
        );
      },
    );
  }
}

// ── Error widgets ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

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
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
