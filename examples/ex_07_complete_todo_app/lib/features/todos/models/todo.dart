/// A single todo item returned by the JSONPlaceholder API.
///
/// [isOptimistic] is a **local-only** flag set to `true` while the create
/// mutation is queued offline. It is never sent to the server; it transitions
/// to `false` once the real server response replaces the temp entry after the
/// offline queue is replayed.
class Todo {
  final String id;
  final String userId;
  final String title;
  final bool completed;

  /// `true` while this todo only exists locally (enqueued offline).
  final bool isOptimistic;

  const Todo({
    required this.id,
    required this.userId,
    required this.title,
    required this.completed,
    this.isOptimistic = false,
  });

  /// Creates a synthetic local-only todo for optimistic UI while offline.
  factory Todo.optimistic({required String title, required String userId}) =>
      Todo(
        id: 'opt-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        title: title,
        completed: false,
        isOptimistic: true,
      );

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: '${json['id']}',
    userId: '${json['userId']}',
    title: json['title'] as String,
    completed: json['completed'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'completed': completed,
    // isOptimistic is never persisted — it is always false on disk.
  };

  Todo copyWith({bool? completed}) => Todo(
    id: id,
    userId: userId,
    title: title,
    completed: completed ?? this.completed,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo &&
          id == other.id &&
          userId == other.userId &&
          title == other.title &&
          completed == other.completed &&
          isOptimistic == other.isOptimistic;

  @override
  int get hashCode => Object.hash(id, userId, title, completed, isOptimistic);

  @override
  String toString() =>
      'Todo(id: $id, userId: $userId, title: $title, '
      'completed: $completed, isOptimistic: $isOptimistic)';
}

/// A single page of todos from the paginated API.
class TodosPage {
  final List<Todo> todos;
  final int page;
  final bool hasMore;

  const TodosPage({
    required this.todos,
    required this.page,
    required this.hasMore,
  });
}

/// Input for the create-todo mutation.
class CreateTodoInput {
  final String title;
  final String userId;

  const CreateTodoInput({required this.title, required this.userId});
}

/// Input for the toggle-complete mutation.
class ToggleTodoInput {
  final String id;
  final bool completed;

  const ToggleTodoInput({required this.id, required this.completed});
}
