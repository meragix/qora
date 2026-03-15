/// A single post — maps directly to the JSONPlaceholder `/posts` schema:
///
/// ```json
/// { "userId": 1, "id": 42, "title": "…", "body": "…" }
/// ```
///
/// [isOptimistic] is a **local-only** flag: `true` while the post is queued
/// offline and not yet confirmed by the server.
class Post {
  final String id;
  final String author; // "User {userId}"
  final String content; // body field from JSONPlaceholder

  /// `true` while this post only exists locally (enqueued offline).
  final bool isOptimistic;

  const Post({
    required this.id,
    required this.author,
    required this.content,
    this.isOptimistic = false,
  });

  /// Constructs a temporary optimistic post shown immediately while offline.
  factory Post.optimistic({required String content}) => Post(
    id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
    author: 'You',
    content: content,
    isOptimistic: true,
  );

  /// Parses a JSONPlaceholder post object.
  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: '${json['id']}',
    author: 'User ${json['userId']}',
    content: (json['body'] as String).replaceAll('\n', ' '),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          id == other.id &&
          content == other.content &&
          isOptimistic == other.isOptimistic;

  @override
  int get hashCode => Object.hash(id, content, isOptimistic);

  @override
  String toString() =>
      'Post(id: $id, author: $author, isOptimistic: $isOptimistic)';
}

/// Local-only settings (never requires a network call).
class AppSettings {
  final bool notificationsEnabled;
  final String theme;

  const AppSettings({this.notificationsEnabled = true, this.theme = 'system'});
}
