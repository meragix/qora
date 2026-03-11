import 'package:ex_03_infinite_scroll/features/feed/data/feed_api.dart';
import 'package:ex_03_infinite_scroll/features/feed/models/feed_page.dart';
import 'package:ex_03_infinite_scroll/features/feed/models/post.dart';
import 'package:ex_03_infinite_scroll/features/feed/ui/compose_sheet.dart';
import 'package:ex_03_infinite_scroll/features/feed/ui/post_tile.dart';
import 'package:ex_03_infinite_scroll/features/feed/ui/widgets/end_of_feed.dart';
import 'package:ex_03_infinite_scroll/features/feed/ui/widgets/load_more_error.dart';
import 'package:ex_03_infinite_scroll/features/feed/ui/widgets/page_loader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scrollController = ScrollController();

  // Stored from the InfiniteQueryBuilder callback so _onScroll can reference
  // the latest state and controller without capturing a stale closure.
  InfiniteQueryController<FeedPage, String>? _controller;
  InfiniteQueryState<FeedPage, String> _latestState = const InfiniteInitial();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    final controller = _controller;
    if (controller == null) return;

    // Trigger next page when within 300 px of the bottom.
    if (pos.extentAfter < 300) {
      if (_latestState case InfiniteSuccess<FeedPage, String>(
        :final hasNextPage,
        :final isFetchingNextPage,
      ) when hasNextPage && !isFetchingNextPage) {
        controller.fetchNextPage();
      }
    }

    // Trigger previous page when within 300 px of the top.
    // Only fires after maxPages has evicted the first loaded page.
    if (pos.extentBefore < 300) {
      if (_latestState case InfiniteSuccess<FeedPage, String>(
        :final hasPreviousPage,
        :final isFetchingPreviousPage,
      ) when hasPreviousPage && !isFetchingPreviousPage) {
        controller.fetchPreviousPage();
      }
    }
  }

  void _openComposeSheet(InfiniteQueryController<FeedPage, String> controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          ComposeSheet(onPublish: (content) => _publish(content, controller)),
    );
  }

  Future<void> _publish(
    String content,
    InfiniteQueryController<FeedPage, String> controller,
  ) async {
    const feedKey = ['feed'];
    final client = context.qora;

    // 1. Snapshot for rollback.
    final snapshot = client.getInfiniteQueryData<FeedPage, String>(feedKey);

    // 2. Optimistic prepend to first page.
    if (snapshot != null && snapshot.isNotEmpty) {
      final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
      final optimisticPost = Post.optimistic(
        id: tempId,
        content: content,
        author: 'You',
      );
      final firstPage = snapshot.pages.first;
      client.setInfiniteQueryData<FeedPage, String>(
        feedKey,
        InfiniteData(
          pages: [
            FeedPage(
              posts: [optimisticPost, ...firstPage.posts],
              nextCursor: firstPage.nextCursor,
              previousCursor: firstPage.previousCursor,
            ),
            ...snapshot.pages.skip(1),
          ],
          pageParams: snapshot.pageParams,
        ),
      );
    }

    try {
      // 3. Fire the real mutation.
      await FeedApi.createPost(content: content, author: 'You');

      // 4. Refetch all loaded pages to replace the temp-ID post with the
      //    real server object. Unlike invalidateInfiniteQuery(), refetch()
      //    preserves the current page count and scroll position.
      await controller.refetch();
    } catch (error) {
      // 5. Rollback: restore the exact pre-mutation snapshot.
      if (snapshot != null) {
        client.setInfiniteQueryData<FeedPage, String>(feedKey, snapshot);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _controller != null
            ? () => _openComposeSheet(_controller!)
            : null,
        tooltip: 'New post',
        child: const Icon(Icons.edit_outlined),
      ),
      body: InfiniteQueryBuilder<FeedPage, String>(
        queryKey: const ['feed'],
        fetcher: FeedApi.getFeed,
        options: InfiniteQueryOptions<FeedPage, String>(
          // Empty string = fetch from the beginning (most recent posts).
          initialPageParam: '',
          getNextPageParam: (last, _) => last.nextCursor,
          // getPreviousPageParam returns non-null only after maxPages evicts
          // the first page, enabling re-fetch on scroll-back to top.
          getPreviousPageParam: (first, _) => first.previousCursor,
          // maxPages: 3 for demo visibility. In production use 8–10 for
          // typical 20-items-per-page feeds.
          maxPages: 3,
          baseOptions: const QoraOptions(
            staleTime: Duration(minutes: 2),
            retryCount: 3,
          ),
        ),
        builder: (context, state, controller) {
          // Capture for scroll listener and FAB.
          _controller = controller;
          _latestState = state;

          final content = switch (state) {
            InfiniteInitial<FeedPage, String>() ||
            InfiniteLoading<FeedPage, String>() => const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading feed…'),
                  ],
                ),
              ),
            ),
            final InfiniteSuccess<FeedPage, String> s => _buildSuccessSliver(
              s,
              controller,
            ),
            final InfiniteFailure<FeedPage, String> f => _buildFailureSliver(
              f,
              controller,
            ),
          };

          return CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: controller.refetch),
              // Previous-page loading indicator (shown at list top after eviction).
              if (state case InfiniteSuccess<FeedPage, String>(
                :final isFetchingPreviousPage,
              ) when isFetchingPreviousPage)
                const SliverToBoxAdapter(child: PageLoader()),
              content,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSuccessSliver(
    InfiniteSuccess<FeedPage, String> state,
    InfiniteQueryController<FeedPage, String> controller,
  ) {
    final posts = state.data.flatten((page) => page.posts);

    return SliverList.builder(
      itemCount: posts.length + 1, // +1 for footer
      itemBuilder: (context, index) {
        if (index < posts.length) {
          return PostTile(post: posts[index]);
        }

        // Footer: next-page spinner, trigger, or end-of-feed message.
        if (state.isFetchingNextPage) return const PageLoader();
        if (state.hasNextPage) {
          return _LoadMoreTrigger(onTap: controller.fetchNextPage);
        }
        return const EndOfFeedBanner();
      },
    );
  }

  Widget _buildFailureSliver(
    InfiniteFailure<FeedPage, String> state,
    InfiniteQueryController<FeedPage, String> controller,
  ) {
    final previous = state.previousData;

    if (previous != null) {
      // Load-more failure: show stale feed + error retry banner at the bottom.
      final posts = previous.flatten((page) => page.posts);
      return SliverList.builder(
        itemCount: posts.length + 1,
        itemBuilder: (context, i) {
          if (i < posts.length) return PostTile(post: posts[i]);
          return LoadMoreErrorBanner(
            error: state.error,
            onRetry: controller.fetchNextPage,
          );
        },
      );
    }

    // First-load failure: full error screen.
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load feed\n${state.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: controller.refetch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

/// Shown in the list footer when more pages exist but no fetch is running.
/// Tapping explicitly triggers the next page; the scroll listener handles
/// the automatic trigger.
class _LoadMoreTrigger extends StatelessWidget {
  final Future<void> Function() onTap;

  const _LoadMoreTrigger({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.expand_more),
          label: const Text('Load more'),
        ),
      ),
    );
  }
}
