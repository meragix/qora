import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import '../data/feed_api.dart';
import '../models/post.dart';

/// The main feed screen.
///
/// Demonstrates all three [NetworkMode] variants and [FetchStatus.paused]
/// handling side-by-side:
///
/// | Query          | NetworkMode        | Behaviour when offline           |
/// |----------------|--------------------|----------------------------------|
/// | `['posts']`    | `online` (default) | Pauses; shows offline empty state|
/// | `['settings']` | `always`           | Never pauses; always succeeds    |
///
/// The [FetchStatus] third builder argument is the key: it distinguishes
/// "waiting for network" (`paused`) from "actively fetching" (`fetching`)
/// without any custom boolean state.
class FeedScreen extends StatelessWidget {
  final FeedApi api;

  const FeedScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return QoraBuilder<List<Post>>(
      queryKey: const ['posts'],
      fetcher: api.getPosts,
      // NetworkMode.online is the default — queries pause when offline and
      // replay automatically on reconnect.
      builder: (context, state, fetchStatus) {
        // ── Offline + no cached data ─────────────────────────────────────
        // Guard matches both Initial (never loaded) and Loading with no prev data.
        final hasNoData =
            state is Initial ||
            (state is Loading<List<Post>> && state.previousData == null);

        if (hasNoData && fetchStatus == FetchStatus.paused) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No connection\nConnect to load the feed',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // ── No data yet (first load, online) ────────────────────────────
        if (hasNoData) {
          return const Center(child: CircularProgressIndicator());
        }

        // ── Error, no previous data ──────────────────────────────────────
        if (state is Failure<List<Post>> && state.previousData == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('${state.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.qora.invalidate(const ['posts']),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // ── Data available (Success, or Loading/Failure with stale data) ─
        final posts = state.dataOrNull ?? [];
        return Column(
          children: [
            // SWR background revalidation indicator
            if (fetchStatus == FetchStatus.fetching)
              const LinearProgressIndicator(minHeight: 2),

            // Offline + stale data: data is visible but revalidation is paused
            if (fetchStatus == FetchStatus.paused)
              _OfflineBanner(
                message: 'Showing cached feed · will refresh on reconnect',
              ),

            // Error banner over stale data
            if (state is Failure<List<Post>>)
              _ErrorBanner(error: '${state.error}'),

            // Feed list
            Expanded(
              child: posts.isEmpty
                  ? const Center(child: Text('No posts yet'))
                  : ListView.builder(
                      itemCount: posts.length,
                      itemBuilder: (_, index) => _PostCard(post: posts[index]),
                    ),
            ),

            // NetworkMode.always demo panel (always visible, even offline)
            const _SettingsTile(),
          ],
        );
      },
    );
  }
}

// ── Post card ────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final Post post;

  const _PostCard({required this.post});

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
                  radius: 14,
                  child: Text(
                    post.author[0],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  post.author,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (post.isOptimistic) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Queued — will sync on reconnect',
                    child: Icon(
                      Icons.schedule,
                      size: 14,
                      color: Colors.orange.shade400,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.content,
              style: TextStyle(
                color: post.isOptimistic ? Colors.grey.shade600 : null,
                fontStyle: post.isOptimistic
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── NetworkMode.always demo ──────────────────────────────────────────────────

/// A settings panel backed by a local query ([NetworkMode.always]).
///
/// This tile is always visible and always loads successfully — even when the
/// feed above is paused because the device is offline.  It demonstrates that
/// `NetworkMode.always` bypasses connectivity checks entirely.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile();

  @override
  Widget build(BuildContext context) {
    return QoraBuilder<AppSettings>(
      queryKey: const ['settings'],
      fetcher: _localFetcher,
      options: const QoraOptions(
        networkMode:
            NetworkMode.always, // never pauses, never waits for connectivity
        staleTime: Duration(hours: 1),
      ),
      builder: (context, state, _) {
        final settings = state.dataOrNull;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune, size: 16),
              const SizedBox(width: 8),
              Text(
                'NetworkMode.always — loads even offline',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (settings != null)
                Icon(
                  settings.notificationsEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        );
      },
    );
  }

  static Future<AppSettings> _localFetcher() async {
    // Tiny delay to show it resolves instantly even offline.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return const AppSettings();
  }
}

// ── Shared inline banners ────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final String message;

  const _OfflineBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 14, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;

  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Error refreshing feed: $error',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
