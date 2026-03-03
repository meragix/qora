import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import '../models/user.dart';
import '../services/fake_api.dart';

/// Demonstrates a per-item query with:
/// - Separate cache key per user: `['users', userId]`
/// - Instant load from cache when navigating back and forward
/// - `previousData` shown during background refresh (graceful degradation)
/// - `updatedAt` timestamp from [Success] state
/// - [FetchStatus.paused] banner when offline
class UserDetailScreen extends StatelessWidget {
  final String userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Detail'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refetch',
            onPressed: () => context.qora.invalidate(['users', userId]),
          ),
        ],
      ),
      body: QoraBuilder<User>(
        queryKey: ['users', userId],
        queryFn: () => FakeApi.getUser(userId),
        options: const QoraOptions(staleTime: Duration(minutes: 5)),
        builder: (context, state, fetchStatus) {
          final offlineBanner = fetchStatus == FetchStatus.paused
              ? const _Banner(icon: Icons.wifi_off, label: 'Offline — showing cached data', color: Colors.orange)
              : null;

          return switch (state) {
            // ── First load ────────────────────────────────────────────────
            Initial() || Loading(previousData: null) => const Center(child: CircularProgressIndicator()),

            // ── Hard error (no cache) ─────────────────────────────────────
            Failure(:final error, previousData: null) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load user\n$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: () => context.qora.invalidate(['users', userId]),
                    ),
                  ],
                ),
              ),
            ),

            // ── Data available ────────────────────────────────────────────
            _ => Column(
              children: [
                ?offlineBanner,
                // Soft error when refresh fails but stale data is still shown
                if (state is Failure<User>)
                  _Banner(
                    icon: Icons.warning_amber_rounded,
                    label: 'Refresh failed: ${state.error}',
                    color: Colors.red,
                  ),
                // Subtle loading indicator during background revalidation
                if (fetchStatus == FetchStatus.fetching) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: _UserDetailView(
                    user: state.dataOrNull!,
                    updatedAt: state.updatedAt,
                    isStale: state is! Success<User>,
                  ),
                ),
              ],
            ),
          };
        },
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _UserDetailView extends StatelessWidget {
  final User user;
  final DateTime? updatedAt;
  final bool isStale;

  const _UserDetailView({required this.user, required this.updatedAt, required this.isStale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 48,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(user.avatar, style: const TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 20),

          // Name
          Text(user.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // Email
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email_outlined, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(user.email, style: theme.textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: 8),

          // ID chip
          Chip(label: Text('ID: ${user.id}'), avatar: const Icon(Icons.tag, size: 16)),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // Cache metadata
          _MetaTile(
            icon: Icons.schedule,
            label: 'Last fetched',
            value: updatedAt != null ? _formatTime(updatedAt!) : 'Stale data',
            valueColor: isStale ? Colors.orange.shade700 : Colors.green.shade700,
          ),
          const SizedBox(height: 8),
          _MetaTile(
            icon: Icons.key,
            label: 'Cache key',
            value: "['users', '${user.id}']",
            valueColor: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 8),
          _MetaTile(
            icon: Icons.timer_outlined,
            label: 'staleTime',
            value: '5 minutes',
            valueColor: theme.colorScheme.secondary,
          ),

          const SizedBox(height: 24),
          const _CacheHint(),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MetaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _MetaTile({required this.icon, required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text('$label: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: valueColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _CacheHint extends StatelessWidget {
  const _CacheHint();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Go back and reopen this screen — the data loads instantly '
                'from cache. After 5 minutes the cache goes stale and a '
                'background refetch fires automatically on reopen.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String label;
  final MaterialColor color;

  const _Banner({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: color.shade50,
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12, color: color.shade700)),
          ),
        ],
      ),
    );
  }
}
