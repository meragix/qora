/// A single post from JSONPlaceholder `/posts`.
class PostItem {
  final String id;
  final String title;
  final String body;
  final String userId;

  const PostItem({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
  });

  factory PostItem.fromJson(Map<String, dynamic> json) => PostItem(
    id: '${json['id']}',
    title: json['title'] as String,
    body: (json['body'] as String).replaceAll('\n', ' '),
    userId: '${json['userId']}',
  );
}

/// One page of posts returned by [JsonPlaceholderApi.getPosts].
class PostsPage {
  final List<PostItem> posts;
  final int page;

  /// `true` when there may be more pages to load.
  final bool hasMore;

  const PostsPage({
    required this.posts,
    required this.page,
    required this.hasMore,
  });
}
