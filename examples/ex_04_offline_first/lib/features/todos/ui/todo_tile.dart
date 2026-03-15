import 'package:flutter/material.dart';

import '../models/todo.dart';

/// A single row in the todo list.
///
/// Renders differently depending on [todo.isPending]:
/// - **Pending** (created offline, not yet confirmed by server): greyed-out
///   italic title, spinner leading, cloud-off trailing with tooltip.
/// - **Confirmed**: normal title, checkbox leading, delete trailing.
class TodoTile extends StatelessWidget {
  final Todo todo;
  final void Function(ToggleTodoInput input) onToggle;
  final void Function(DeleteTodoInput input) onDelete;

  const TodoTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: todo.isPending
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Checkbox(
              value: todo.completed,
              onChanged: (_) => onToggle(
                ToggleTodoInput(id: todo.id, completed: !todo.completed),
              ),
            ),
      title: Text(
        todo.title,
        style: TextStyle(
          color: todo.isPending
              ? Colors.grey.shade500
              : todo.completed
              ? Colors.grey.shade600
              : null,
          fontStyle: todo.isPending ? FontStyle.italic : FontStyle.normal,
          decoration: !todo.isPending && todo.completed
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
      trailing: todo.isPending
          ? Tooltip(
              message: 'Will sync when online',
              child: Icon(
                Icons.cloud_off,
                size: 16,
                color: Colors.grey.shade400,
              ),
            )
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.grey.shade600,
              onPressed: () => onDelete(DeleteTodoInput(id: todo.id)),
            ),
    );
  }
}
