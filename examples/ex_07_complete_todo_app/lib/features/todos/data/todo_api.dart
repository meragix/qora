import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/todo.dart';

/// HTTP client for the JSONPlaceholder REST API.
///
/// Uses page-based pagination: [getTodosPage] maps to
/// `GET /todos?userId={id}&_page={page}&_limit=10`.
///
/// JSONPlaceholder doesn't actually paginate, so [TodosPage.hasMore] is
/// derived heuristically: if a full page of 10 items was returned there may
/// be more; if fewer were returned we're on the last page.
class TodoApi {
  static const String _base = 'jsonplaceholder.typicode.com';
  static const int _pageSize = 10;

  /// Fetches one page of todos for [userId].
  Future<TodosPage> getTodosPage(String userId, {required int page}) async {
    final uri = Uri.https(_base, '/todos', {
      'userId': userId,
      '_page': '$page',
      '_limit': '$_pageSize',
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load todos: ${response.statusCode}');
    }
    final list = (jsonDecode(response.body) as List)
        .map((e) => Todo.fromJson(e as Map<String, dynamic>))
        .toList();

    return TodosPage(
      todos: list,
      page: page,
      hasMore: list.length == _pageSize,
    );
  }

  /// Creates a new todo on the server.
  Future<Todo> createTodo(CreateTodoInput input) async {
    final uri = Uri.https(_base, '/todos');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': input.title,
        'userId': input.userId,
        'completed': false,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create todo: ${response.statusCode}');
    }
    return Todo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Toggles the completed state of [input.id].
  Future<Todo> toggleTodo(ToggleTodoInput input) async {
    final uri = Uri.https(_base, '/todos/${input.id}');
    final response = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'completed': input.completed}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to toggle todo: ${response.statusCode}');
    }
    return Todo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Deletes the todo with [id].
  Future<void> deleteTodo(String id) async {
    final uri = Uri.https(_base, '/todos/$id');
    final response = await http.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete todo: ${response.statusCode}');
    }
  }
}
