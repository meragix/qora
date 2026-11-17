import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import '../todos/data/todo_mutations.dart';
import '../todos/models/todo.dart';

/// App bar button: how many writes are waiting, and whether one needs the
/// user. Opens [SyncPanel].
class SyncButton extends StatelessWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    return MutationQueueBuilder(
      builder: (context, entries, _) {
        final stuck = entries.any(_needsDecision);
        return IconButton(
          tooltip: entries.isEmpty
              ? 'Everything is synced'
              : '${entries.length} change(s) to sync',
          icon: Badge(
            isLabelVisible: entries.isNotEmpty,
            backgroundColor: stuck ? Colors.red : null,
            label: Text('${entries.length}'),
            child: Icon(stuck ? Icons.sync_problem : Icons.sync),
          ),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => SyncPanel(client: context.qora),
          ),
        );
      },
    );
  }
}

bool _needsDecision(QueuedMutation entry) =>
    entry.status == QueuedMutationStatus.blocked ||
    entry.status == QueuedMutationStatus.failed;

/// Lists `client.mutationQueue.entries`, live, and lets the user decide on a
/// write the server refused: resend it, or drop it.
class SyncPanel extends StatelessWidget {
  const SyncPanel({super.key, required this.client});

  final QoraClient client;

  @override
  Widget build(BuildContext context) {
    final queue = client.mutationQueue;
    return MutationQueueBuilder(
      client: client,
      builder: (context, entries, _) {
        if (entries.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text('Everything is synced')),
          );
        }
        final titles = _titles(entries);
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final entry in entries)
              ListTile(
                key: ValueKey(entry.mutationId),
                leading: _StatusIcon(entry.status),
                title: Text(_describe(entry, titles)),
                subtitle: Text(_status(entry)),
                trailing: _needsDecision(entry)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Same payload, same mutationId: the server still
                          // deduplicates it.
                          TextButton(
                            onPressed: () => queue.retry(entry.mutationId),
                            child: const Text('Retry'),
                          ),
                          // The writes it held become blocked in turn.
                          TextButton(
                            onPressed: () => queue.discard(entry.mutationId),
                            child: const Text('Discard'),
                          ),
                        ],
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }

  /// Titles for the rows: the cached list, plus the todos created offline.
  Map<String, String> _titles(List<QueuedMutation> entries) => {
    for (final todo in client.getQueryData<List<Todo>>(todosKey) ?? <Todo>[])
      todo.id: todo.title,
    for (final entry in entries)
      if (entry.variables case CreateTodoInput(:final id, :final title))
        id: title,
  };

  String _describe(QueuedMutation entry, Map<String, String> titles) =>
      switch (entry.variables) {
        CreateTodoInput(:final title) => 'Create "$title"',
        ToggleTodoInput(:final id, :final completed) =>
          '${completed ? 'Complete' : 'Reopen'} "${titles[id] ?? id}"',
        DeleteTodoInput(:final id) => 'Delete "${titles[id] ?? id}"',
        _ => entry.key,
      };

  String _status(QueuedMutation entry) {
    final error = entry.lastError;
    return switch (entry.status) {
      QueuedMutationStatus.queued when entry.attempts > 0 =>
        'Retrying (attempt ${entry.attempts + 1})',
      QueuedMutationStatus.queued => 'Waiting to be sent',
      QueuedMutationStatus.sending => 'Sending',
      QueuedMutationStatus.blocked when error != null => 'Refused: $error',
      QueuedMutationStatus.blocked => 'A write before it was discarded',
      QueuedMutationStatus.held => 'Waiting for the write above',
      QueuedMutationStatus.failed => 'Refused: $error',
    };
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon(this.status);

  final QueuedMutationStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
    QueuedMutationStatus.queued => const Icon(Icons.schedule),
    QueuedMutationStatus.sending => const SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    QueuedMutationStatus.blocked || QueuedMutationStatus.failed => Icon(
      Icons.error,
      color: Colors.red.shade400,
    ),
    QueuedMutationStatus.held => const Icon(Icons.pause_circle_outline),
  };
}
