import 'post.dart';

/// A single page of feed posts returned by the server.
///
/// [nextCursor] is the cursor to pass to fetch the next (older) page.
/// Null when there are no more older posts.
///
/// [previousCursor] is the cursor to pass to re-fetch the page immediately
/// before this one. Used by [maxPages] windowed paging to recover evicted
/// pages when the user scrolls back to the top.
/// Null when this page is already the newest (page 1).
class FeedPage {
  final List<Post> posts;
  final String? nextCursor;
  final String? previousCursor;

  const FeedPage({required this.posts, this.nextCursor, this.previousCursor});
}
