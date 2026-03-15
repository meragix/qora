/// A single todo item.
///
/// [isPending] is a **local-only** flag set to `true` for todos created
/// offline via an optimistic response.  It is never stored on the server;
/// it transitions to `false` once the real server response replaces the
/// temp entry after the offline queue is replayed.
class Todo {
  final String id;
  final String title;
  final bool completed;

  /// `true` while this todo only exists locally (enqueued offline).
  final bool isPending;

  const Todo({
    required this.id,
    required this.title,
    required this.completed,
    this.isPending = false,
  });

  Todo copyWith({
    String? id,
    String? title,
    bool? completed,
    bool? isPending,
  }) => Todo(
    id: id ?? this.id,
    title: title ?? this.title,
    completed: completed ?? this.completed,
    isPending: isPending ?? this.isPending,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
    // isPending is never persisted — it is always false on disk.
  };

  factory Todo.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return Todo(
      id: map['id'] as String,
      title: map['title'] as String,
      completed: map['completed'] as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo &&
          id == other.id &&
          title == other.title &&
          completed == other.completed &&
          isPending == other.isPending;

  @override
  int get hashCode => Object.hash(id, title, completed, isPending);

  @override
  String toString() =>
      'Todo(id: $id, title: $title, completed: $completed, isPending: $isPending)';
}

/// Input for the create-todo mutation.
class CreateTodoInput {
  final String title;
  const CreateTodoInput({required this.title});
}

/// Input for the toggle-complete mutation.
class ToggleTodoInput {
  final String id;
  final bool completed;
  const ToggleTodoInput({required this.id, required this.completed});
}

/// Input for the delete-todo mutation.
class DeleteTodoInput {
  final String id;
  const DeleteTodoInput({required this.id});
}
