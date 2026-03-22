import 'package:flutter/material.dart';

import '../models/todo.dart';

/// A single todo row in the infinite-scroll list.
///
/// | State                  | Leading               | Title style     | Trailing          |
/// |------------------------|-----------------------|-----------------|-------------------|
/// | Optimistic (queued)    | schedule icon (orange)| grey + italic   | —                 |
/// | Optimistic (sending)   | small spinner         | grey + italic   | —                 |
/// | Completed              | checked checkbox       | strikethrough   | delete button     |
/// | Active                 | unchecked checkbox     | normal          | delete button     |
class TodoTile extends StatelessWidget {
  final Todo todo;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  /// When [todo.isOptimistic] is `true`, this flag controls the leading icon:
  /// - `true`  → schedule icon with "Queued" tooltip (offline queue)
  /// - `false` → small spinner (online request in flight)
  final bool isQueued;

  const TodoTile({
    super.key,
    required this.todo,
    this.onToggle,
    this.onDelete,
    this.isQueued = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: todo.isOptimistic
          ? isQueued
              ? Tooltip(
                  message: 'Queued — will sync on reconnect',
                  child: Icon(Icons.schedule, color: Colors.orange.shade400),
                )
              : const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
          : Checkbox(
              value: todo.completed,
              onChanged: onToggle == null ? null : (_) => onToggle!(),
            ),
      title: Text(
        todo.title,
        style: TextStyle(
          color: todo.isOptimistic
              ? theme.colorScheme.outline
              : todo.completed
              ? theme.colorScheme.outline
              : null,
          fontStyle: todo.isOptimistic ? FontStyle.italic : FontStyle.normal,
          decoration: todo.completed ? TextDecoration.lineThrough : null,
          decorationColor: theme.colorScheme.outline,
        ),
      ),
      trailing: todo.isOptimistic
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              color: theme.colorScheme.error.withValues(alpha: 0.7),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
      onTap: todo.isOptimistic ? null : onToggle,
    );
  }
}
