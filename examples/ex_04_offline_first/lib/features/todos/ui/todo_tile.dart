import 'package:flutter/material.dart';

import '../data/todo_view.dart';

/// A row of the list.
///
/// A todo with queued writes stays fully usable: a toggle or a delete made
/// before the server confirmed its creation is queued behind it, in the same
/// scope. The trailing icon shows where it stands.
class TodoTile extends StatelessWidget {
  const TodoTile({
    super.key,
    required this.view,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoView view;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final todo = view.todo;
    return ListTile(
      leading: Checkbox(value: todo.completed, onChanged: (_) => onToggle()),
      title: Text(
        todo.title,
        style: TextStyle(
          color: todo.completed ? Colors.grey.shade600 : null,
          decoration: todo.completed ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          switch (view.sync) {
            SyncState.synced => const SizedBox.shrink(),
            SyncState.pending => Tooltip(
              message: 'Waiting to sync',
              child: Icon(
                Icons.cloud_upload_outlined,
                key: const ValueKey('pending'),
                size: 18,
                color: Colors.grey.shade500,
              ),
            ),
            SyncState.needsAttention => Tooltip(
              message: 'Not synced: open the sync panel',
              child: Icon(
                Icons.error_outline,
                key: const ValueKey('needsAttention'),
                size: 18,
                color: Colors.red.shade400,
              ),
            ),
          },
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.grey.shade600,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
