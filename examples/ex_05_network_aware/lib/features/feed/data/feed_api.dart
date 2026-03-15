import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/post.dart';

/// HTTP layer backed by [JSONPlaceholder](https://jsonplaceholder.typicode.com).
///
/// Uses the real network — no simulation.  Qora's [NetworkMode.online] ensures
/// [getPosts] and [createPost] are **never called** when the device is offline:
/// Qora pauses the query or enqueues the mutation before reaching this layer.
///
/// [getSettings] uses [NetworkMode.always] in the widget and never calls the
/// network, demonstrating that local queries are independent of connectivity.
class FeedApi {
  static const _base = 'https://jsonplaceholder.typicode.com';

  final http.Client _client;

  FeedApi({http.Client? client}) : _client = client ?? http.Client();

  /// GET /posts?_limit=20 — returns the 20 most recent posts.
  Future<List<Post>> getPosts() async {
    final uri = Uri.parse('$_base/posts?_limit=20');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw ApiException(
        'GET /posts failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    // Reverse so newest appears first (JSONPlaceholder returns oldest first).
    return list.reversed
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /posts — JSONPlaceholder accepts the request and echoes back id:101.
  ///
  /// Note: JSONPlaceholder is a fake API — posts are not actually persisted.
  /// On the next [getPosts] call the list returns to its original state.
  /// This is expected behaviour for a demo server.
  Future<Post> createPost(String content) async {
    final uri = Uri.parse('$_base/posts');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'title': content, 'body': content, 'userId': 1}),
    );

    if (response.statusCode != 201) {
      throw ApiException(
        'POST /posts failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    return Post.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, {required this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
