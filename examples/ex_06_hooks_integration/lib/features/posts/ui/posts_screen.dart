import 'package:ex_06_hooks_integration/features/posts/models/posts_page.dart';
import 'package:ex_06_hooks_integration/shared/api/json_placeholder_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_hooks/qora_hooks.dart';

/// Posts screen demonstrating [useInfiniteQuery] for infinite scroll.
///
/// [useInfiniteQuery] accumulates pages in [InfiniteQueryHandle.pages].
/// When the sentinel item at the end of the list is built, [fetchNextPage]
/// is called automatically — no scroll listeners, no [StatefulWidget].
///
/// [getNextPageParam] drives termination: returning `null` sets
/// [InfiniteQueryHandle.hasNextPage] to `false` and stops further fetches.
class PostsScreen extends HookWidget {
  final JsonPlaceholderApi api;

  const PostsScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final query = useInfiniteQuery<PostsPage, int>(
      key: const ['posts'],
      fetcher: (page) => api.getPosts(page: page),
      getNextPageParam: (lastPage) =>
          lastPage.hasMore ? lastPage.page + 1 : null,
      initialPageParam: 1,
    );

    // ── First load ────────────────────────────────────────────────────────
    if (query.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ── Error with no data ────────────────────────────────────────────────
    if (query.error != null && query.pages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('${query.error}', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              // Re-mount the widget to restart the query.
              FilledButton(
                onPressed: () => query.fetchNextPage(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // ── Data available ────────────────────────────────────────────────────
    final posts = query.pages.expand((p) => p.posts).toList();

    return ListView.builder(
      // +1 for the sentinel / "load more" item at the bottom.
      itemCount: posts.length + (query.hasNextPage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == posts.length) {
          // Auto-trigger next page when the sentinel scrolls into view.
          if (!query.isFetchingNextPage) query.fetchNextPage();
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _PostTile(post: posts[index]);
      },
    );
  }
}

// ── Post tile ─────────────────────────────────────────────────────────────────

class _PostTile extends StatelessWidget {
  final PostItem post;

  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  child: Text(
                    post.userId,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(post.body, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
