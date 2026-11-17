import 'dart:math';

/// A todo as the server knows it.
class Todo {
  final String id;
  final String title;
  final bool completed;

  const Todo({required this.id, required this.title, required this.completed});

  Todo copyWith({String? title, bool? completed}) => Todo(
    id: id,
    title: title ?? this.title,
    completed: completed ?? this.completed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
  };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as String,
    title: json['title'] as String,
    completed: json['completed'] as bool,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo &&
          id == other.id &&
          title == other.title &&
          completed == other.completed;

  @override
  int get hashCode => Object.hash(id, title, completed);

  @override
  String toString() => 'Todo(id: $id, title: $title, completed: $completed)';
}

final _random = Random();

/// Input of `todos.create`.
///
/// The id is generated on the device, not by the server: a todo created
/// offline has its final id right away, so a toggle or a delete queued after
/// it can target it, and its scope (`todo:<id>`) orders them behind the
/// create.
class CreateTodoInput {
  final String id;
  final String title;

  const CreateTodoInput({required this.id, required this.title});

  factory CreateTodoInput.newTodo(String title) => CreateTodoInput(
    id: '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 30)}',
    title: title,
  );

  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  factory CreateTodoInput.fromJson(Map<String, dynamic> json) =>
      CreateTodoInput(id: json['id'] as String, title: json['title'] as String);
}

/// Input of `todos.toggle`.
class ToggleTodoInput {
  final String id;
  final bool completed;

  const ToggleTodoInput({required this.id, required this.completed});

  Map<String, dynamic> toJson() => {'id': id, 'completed': completed};

  factory ToggleTodoInput.fromJson(Map<String, dynamic> json) =>
      ToggleTodoInput(
        id: json['id'] as String,
        completed: json['completed'] as bool,
      );
}

/// Input of `todos.delete`.
class DeleteTodoInput {
  final String id;

  const DeleteTodoInput({required this.id});

  Map<String, dynamic> toJson() => {'id': id};

  factory DeleteTodoInput.fromJson(Map<String, dynamic> json) =>
      DeleteTodoInput(id: json['id'] as String);
}
