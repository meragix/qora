class Post {
  final String id;
  final String content;
  final String author;
  final String avatar;
  final DateTime createdAt;
  final bool isOptimistic;

  const Post({
    required this.id,
    required this.content,
    required this.author,
    required this.avatar,
    required this.createdAt,
    this.isOptimistic = false,
  });

  factory Post.optimistic({
    required String id,
    required String content,
    required String author,
  }) {
    return Post(
      id: id,
      content: content,
      author: author,
      avatar: '✍️',
      createdAt: DateTime.now(),
      isOptimistic: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Post(id: $id, author: $author)';
}
