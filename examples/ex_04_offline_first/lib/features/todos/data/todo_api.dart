import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/connectivity/simulated_connectivity_manager.dart';
import '../models/todo.dart';

/// Simulated REST API, kept in memory for the demo.
///
/// - Every call takes [latency], then fails with [OfflineException] if the
///   device is offline by then.
/// - Writes take an idempotency key and apply each key once: a write sent
///   again, after a restart or a lost response, returns the first result
///   instead of being applied twice.
/// - A title containing "reject" fails with a 422, to show a write the server
///   refuses for good.
///
/// It is the server: it outlives the app's simulated restarts.
class TodoApi {
  TodoApi(this._network, {this.latency = const Duration(milliseconds: 600)});

  final SimulatedNetwork _network;
  final Duration latency;

  final List<Todo> _store = [
    const Todo(id: '1', title: 'Buy groceries', completed: false),
    const Todo(id: '2', title: 'Read a book', completed: true),
    const Todo(id: '3', title: 'Go for a walk', completed: false),
  ];

  final Map<String, Object?> _applied = {};

  /// What the server holds, without a request.
  @visibleForTesting
  List<Todo> get serverTodos => List.unmodifiable(_store);

  Future<void> _roundTrip() async {
    if (_network.isOffline) throw const OfflineException();
    await Future<void>.delayed(latency);
    if (_network.isOffline) throw const OfflineException();
  }

  Future<List<Todo>> getTodos() async {
    await _roundTrip();
    return List.unmodifiable(_store);
  }

  Future<Todo> createTodo(
    CreateTodoInput input, {
    required String idempotencyKey,
  }) => _once(idempotencyKey, () {
    if (input.title.toLowerCase().contains('reject')) {
      throw const ApiException(422, 'This title is not allowed');
    }
    final todo = Todo(id: input.id, title: input.title, completed: false);
    // Create-as-upsert on the client-generated id.
    _store
      ..removeWhere((t) => t.id == input.id)
      ..add(todo);
    return todo;
  });

  Future<Todo> toggleTodo(
    ToggleTodoInput input, {
    required String idempotencyKey,
  }) => _once(idempotencyKey, () {
    final index = _store.indexWhere((t) => t.id == input.id);
    if (index == -1) throw const ApiException(404, 'Todo not found');
    return _store[index] = _store[index].copyWith(completed: input.completed);
  });

  Future<void> deleteTodo(
    DeleteTodoInput input, {
    required String idempotencyKey,
  }) => _once(idempotencyKey, () {
    _store.removeWhere((t) => t.id == input.id);
  });

  Future<T> _once<T>(String idempotencyKey, T Function() apply) async {
    await _roundTrip();
    if (_applied.containsKey(idempotencyKey)) {
      return _applied[idempotencyKey] as T;
    }
    final result = apply();
    _applied[idempotencyKey] = result;
    return result;
  }
}

class OfflineException implements Exception {
  const OfflineException();

  @override
  String toString() => 'No network connection';
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  /// A 4xx means the request itself is wrong: sending it again cannot help.
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  @override
  String toString() => '$statusCode: $message';
}
