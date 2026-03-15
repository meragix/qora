import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/posts/models/posts_page.dart';
import '../../features/profile/models/user.dart';

/// HTTP client for JSONPlaceholder (https://jsonplaceholder.typicode.com).
///
/// NOTE: JSONPlaceholder is a fake REST API — POST/PUT calls return realistic
/// responses but changes are not actually persisted server-side.
class JsonPlaceholderApi {
  static const _base = 'jsonplaceholder.typicode.com';
  static const _pageSize = 10;

  final http.Client _client;

  JsonPlaceholderApi({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches a user by [id].
  Future<User> getUser(String id) async {
    final response = await _client.get(Uri.https(_base, '/users/$id'));
    _checkStatus(response);
    return User.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Updates a user's display name.  Returns the (fake) updated user.
  Future<User> updateUser(UpdateUserInput input) async {
    final response = await _client.put(
      Uri.https(_base, '/users/${input.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': input.name, 'username': input.username}),
    );
    _checkStatus(response);
    // JSONPlaceholder echoes back a merged object.
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return User.fromJson({...json, 'id': int.parse(input.id)});
  }

  /// Fetches a page of posts.  [page] is 1-based.
  Future<PostsPage> getPosts({required int page}) async {
    final response = await _client.get(
      Uri.https(
        _base,
        '/posts',
        {'_page': '$page', '_limit': '$_pageSize'},
      ),
    );
    _checkStatus(response);
    final items = (jsonDecode(response.body) as List)
        .cast<Map<String, dynamic>>()
        .map(PostItem.fromJson)
        .toList();

    return PostsPage(
      posts: items,
      page: page,
      // JSONPlaceholder has 100 posts total; fewer than pageSize means last page.
      hasMore: items.length >= _pageSize,
    );
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
}

/// Input for [JsonPlaceholderApi.updateUser].
class UpdateUserInput {
  final String id;
  final String name;
  final String username;

  const UpdateUserInput({
    required this.id,
    required this.name,
    required this.username,
  });
}
