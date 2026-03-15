import 'dart:async';

import '../models/todo.dart';

/// Simulated in-memory HTTP layer for the offline-first demo.
///
/// Mimics the behavior of a real REST API:
/// - Artificial 600 ms latency on every call.
/// - Throws [OfflineException] when [isOffline] is `true` — this is what
///   triggers `FetchStatus.paused` and the offline mutation queue.
///
/// In a real app, replace this with an actual HTTP client (e.g. Dio).
class TodoApi {
  final List<Todo> _store = [
    const Todo(id: '1', title: 'Buy groceries', completed: false),
    const Todo(id: '2', title: 'Read a book', completed: true),
    const Todo(id: '3', title: 'Go for a walk', completed: false),
  ];

  int _nextId = 4;

  /// Controlled externally by [SimulatedConnectivityManager].
  bool isOffline = false;

  Future<void> _simulateLatency() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (isOffline) throw const OfflineException();
  }

  Future<List<Todo>> getTodos() async {
    await _simulateLatency();
    return List<Todo>.from(_store);
  }

  Future<Todo> createTodo(CreateTodoInput input) async {
    await _simulateLatency();
    final todo = Todo(id: '${_nextId++}', title: input.title, completed: false);
    _store.add(todo);
    return todo;
  }

  Future<Todo> toggleTodo(ToggleTodoInput input) async {
    await _simulateLatency();
    final index = _store.indexWhere((t) => t.id == input.id);
    if (index == -1) throw StateError('Todo ${input.id} not found');
    final updated = _store[index].copyWith(completed: input.completed);
    _store[index] = updated;
    return updated;
  }

  Future<void> deleteTodo(DeleteTodoInput input) async {
    await _simulateLatency();
    _store.removeWhere((t) => t.id == input.id);
  }
}

class OfflineException implements Exception {
  const OfflineException();

  @override
  String toString() => 'OfflineException: No network connection';
}
