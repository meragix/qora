import 'dart:async';
import 'dart:math';

import 'package:ex_03_infinite_scroll/features/feed/models/feed_page.dart';
import 'package:ex_03_infinite_scroll/features/feed/models/post.dart';
import 'package:flutter/foundation.dart';

/// Simulates a cursor-based REST feed API with configurable latency and
/// probabilistic create failures.
///
/// ## Cursor design
///
/// The cursor is the ID of the **last post on the previous page** (i.e. the
/// boundary post). Passing that ID to [getFeed] returns the next 20 posts
/// after that boundary.
///
/// Empty string (`''`) is the sentinel for "start from the beginning"
/// (fetch the most-recent 20 posts).
///
/// ## Windowed paging
///
/// Each page embeds a [FeedPage.previousCursor] — the cursor that, when
/// passed to [getFeed], re-fetches the page immediately before this one.
/// When [InfiniteQueryOptions.maxPages] evicts the first page, the new
/// first page's [FeedPage.previousCursor] becomes non-null, which sets
/// [InfiniteSuccess.hasPreviousPage] = true and allows re-fetching the
/// dropped page on scroll-back.
///
/// ## Note on fake-server cursor stability
///
/// In a production server, cursors are stable even after new posts are
/// inserted because they reference a stable server-side offset. In this
/// in-memory simulation, inserting a post at index 0 can shift which posts
/// fall into subsequent pages — this is a known demo limitation. Stable
/// cursor behaviour is exactly what [FeedPage.previousCursor] + cursor IDs
/// provide in a real backend.
class FeedApi {
  static const _pageSize = 20;
  static const _delay = Duration(milliseconds: 700);
  static final _random = Random();

  // Mutable so that createPost() can insert at [0] and refetch() picks it up.
  static final List<Post> _posts = _generatePosts();

  static List<Post> _generatePosts() {
    return List.generate(100, (i) {
      final n = i + 1;
      return Post(
        id: 'p${n.toString().padLeft(3, '0')}',
        content: _contents[i % _contents.length],
        author: _authors[i % _authors.length],
        avatar: _avatars[i % _avatars.length],
        createdAt: DateTime.now().subtract(Duration(minutes: n * 15)),
      );
    });
  }

  /// Fetches a page of posts.
  ///
  /// [cursor] is the ID of the last post on the previous page, or `''` to
  /// fetch from the beginning (most recent posts first).
  static Future<FeedPage> getFeed(String cursor) async {
    debugPrint(
      'FeedApi.getFeed(cursor: ${cursor.isEmpty ? '<start>' : cursor})',
    );
    await Future<void>.delayed(_delay);

    final int startIndex;
    if (cursor.isEmpty) {
      startIndex = 0;
    } else {
      final idx = _posts.indexWhere((p) => p.id == cursor);
      if (idx == -1) {
        // Cursor not found — fall back to the beginning (graceful degradation).
        debugPrint(
          'FeedApi: cursor "$cursor" not found, falling back to start',
        );
        startIndex = 0;
      } else {
        startIndex = idx + 1;
      }
    }

    final endIndex = min(startIndex + _pageSize, _posts.length);
    final pagePosts = _posts.sublist(startIndex, endIndex);

    // nextCursor: ID of the last item on this page, signals "more posts exist".
    final String? nextCursor = endIndex < _posts.length
        ? pagePosts.last.id
        : null;

    // previousCursor: the cursor that re-fetches the page immediately before
    // this one. Used by maxPages windowed paging to recover evicted pages.
    final String? previousCursor;
    if (startIndex == 0) {
      previousCursor = null; // This IS the first page; no previous page exists.
    } else {
      final prevStart = startIndex - _pageSize;
      // prevStart <= 0 means the previous page started at the beginning.
      previousCursor = prevStart <= 0 ? '' : _posts[prevStart - 1].id;
    }

    debugPrint(
      'FeedApi.getFeed: returned ${pagePosts.length} posts '
      '(nextCursor: $nextCursor, previousCursor: $previousCursor)',
    );

    return FeedPage(
      posts: pagePosts,
      nextCursor: nextCursor,
      previousCursor: previousCursor,
    );
  }

  /// Simulates creating a new post.
  ///
  /// Fails ~20 % of the time to demonstrate optimistic rollback.
  /// On success, inserts the post at [0] so that a subsequent [getFeed('')]
  /// call includes it at the top of the feed.
  static Future<Post> createPost({
    required String content,
    required String author,
  }) async {
    debugPrint('FeedApi.createPost("$content") — sending…');
    await Future<void>.delayed(_delay);

    if (_random.nextDouble() < 0.2) {
      debugPrint(
        'FeedApi.createPost — simulated server error (20 % failure mode)',
      );
      throw Exception(
        'Server error: failed to publish post. Please try again.',
      );
    }

    final post = Post(
      id: 'p${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      author: author,
      avatar: '🧑‍💻',
      createdAt: DateTime.now(),
    );

    // Insert at the front so refetch() picks up the new post on the first page.
    _posts.insert(0, post);
    debugPrint('FeedApi.createPost — done (id: ${post.id})');
    return post;
  }

  // ── Sample content ─────────────────────────────────────────────────────────

  static const List<String> _contents = [
    'Just shipped a new feature! The infinite scroll now uses cursor-based pagination.',
    'Flutter performance tip: use SliverList.builder to render only visible items.',
    'TIL: Dart records make data classes incredibly clean. No more boilerplate!',
    'Qora\'s maxPages windowing keeps memory bounded even after hours of scrolling.',
    'Optimistic updates feel magical — the UI responds instantly, rollback is automatic.',
    'State management doesn\'t have to be complex. Server state and UI state are different.',
    'Cursor-based pagination eliminates offset drift when posts are inserted mid-scroll.',
    'SWR caching: show stale data immediately, refetch in the background.',
    'The key to smooth infinite scroll: render only what\'s visible, bound the data.',
    'Dart null-safety + sealed classes = exhaustive pattern matching at compile time.',
    'Pull-to-refresh with refetch() re-validates all loaded pages in sequence.',
    'InfiniteFailure.previousData means a failed page load never blanks your feed.',
    'hasPreviousPage becomes true when maxPages evicts your first loaded page.',
    'fetchPreviousPage() re-fetches the evicted page — the feed is reconstructed seamlessly.',
    'setInfiniteQueryData lets you write directly into the paginated cache.',
    'QoraClient is platform-agnostic Dart — the Flutter package is just a thin wrapper.',
    'Background revalidation: data stays fresh without blocking the UI.',
    'The staleTime option controls when a query is considered stale and needs revalidation.',
    'retryCount + exponential backoff: flaky networks are handled automatically.',
    'One QoraKey can be observed by multiple widgets simultaneously.',
  ];

  static const List<String> _authors = [
    'Alice Johnson',
    'Bob Smith',
    'Charlie Brown',
    'Diana Prince',
    'Eve Davis',
    'Frank Miller',
    'Grace Hopper',
    'Hank Pym',
    'Iris West',
    'Jake Long',
  ];

  static const List<String> _avatars = [
    '👩‍💼',
    '👨‍💻',
    '👨‍🎨',
    '👩‍🚀',
    '👩‍🔬',
    '👨‍🏫',
    '👩‍💻',
    '🧑‍🔧',
    '👩‍⚕️',
    '👨‍🎤',
  ];
}
