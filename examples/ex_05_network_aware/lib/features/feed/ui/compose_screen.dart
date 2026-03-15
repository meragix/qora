import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import '../data/feed_api.dart';
import '../models/post.dart';

/// Compose screen — demonstrates [OfflineMutationQueue] + `isOptimistic`.
///
/// Key behaviours:
/// - **Online**: post is sent immediately; feed is invalidated on success.
/// - **Offline**: post is shown instantly via [optimisticResponse] with a
///   "pending sync" indicator.  The mutation is enqueued and replayed in FIFO
///   order on reconnect.
/// - `onSuccess` fires only for **real** server confirmations
///   (`isOptimistic: false`) to avoid invalidating on the optimistic write.
class ComposeScreen extends StatefulWidget {
  final FeedApi api;

  const ComposeScreen({super.key, required this.api});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QoraMutationBuilder<Post, String, void>(
      queryKey: const ['posts'],
      mutator: widget.api.createPost,
      options: MutationOptions(
        offlineQueue: true,
        // Provides an immediate local result while the mutation waits offline.
        optimisticResponse: (content) => Post.optimistic(content: content),
        // onSuccess only runs for real server success (isOptimistic: false).
        onSuccess: (_, _, _) async => context.qora.invalidate(const ['posts']),
      ),
      builder: (context, state, mutate) {
        final isQueued =
            state is MutationSuccess<Post, String> && state.isOptimistic;
        final isPending = state.isPending;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Queued indicator ────────────────────────────────────────
              if (isQueued)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Post queued — will sync when back online',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Section header ──────────────────────────────────────────
              Text(
                'What\'s on your mind?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              // ── Text field ──────────────────────────────────────────────
              TextField(
                controller: _controller,
                maxLines: 5,
                enabled: !isPending,
                decoration: InputDecoration(
                  hintText: 'Write a post…',
                  border: const OutlineInputBorder(),
                  filled: isPending,
                  fillColor: Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 16),

              // ── Submit button ───────────────────────────────────────────
              FilledButton.icon(
                onPressed: isPending
                    ? null
                    : () async {
                        final text = _controller.text.trim();
                        if (text.isEmpty) return;
                        await mutate(text);
                        _controller.clear();
                      },
                icon: Icon(isQueued ? Icons.schedule : Icons.send),
                label: Text(
                  isPending
                      ? 'Sending…'
                      : isQueued
                      ? 'Queued'
                      : 'Post',
                ),
              ),

              const SizedBox(height: 24),

              // ── Explanation panel ───────────────────────────────────────
              _ExplanationPanel(isQueued: isQueued),
            ],
          ),
        );
      },
    );
  }
}

class _ExplanationPanel extends StatelessWidget {
  final bool isQueued;

  const _ExplanationPanel({required this.isQueued});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _Bullet(
            icon: Icons.wifi_off,
            text: 'Post while offline → optimistic response shown immediately',
            highlight: isQueued,
          ),
          _Bullet(
            icon: Icons.queue,
            text: 'Mutation enqueued in OfflineMutationQueue (FIFO)',
            highlight: isQueued,
          ),
          _Bullet(
            icon: Icons.wifi,
            text: 'On reconnect → queue replayed → feed invalidated',
          ),
          _Bullet(
            icon: Icons.check_circle_outline,
            text: 'onSuccess fires only for real server confirmation',
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;

  const _Bullet({
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight
                ? Colors.orange.shade600
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: highlight
                    ? Colors.orange.shade700
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: highlight ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
