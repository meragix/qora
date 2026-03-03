import 'package:flutter/material.dart';
import 'package:flutter_qora/flutter_qora.dart';

import '../models/user.dart';
import '../services/fake_api.dart';
import 'user_detail_screen.dart';

class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User List'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Invalidate & refetch',
            onPressed: () => context.qora.invalidateWhere((key) => key.firstOrNull == 'users'),
          ),
        ],
      ),
      body: QoraBuilder<List<User>>(
        queryKey: const ['users'],
        queryFn: FakeApi.getUsers,
        options: const QoraOptions(staleTime: Duration(minutes: 5), cacheTime: Duration(minutes: 10)),
        builder: (context, state, fetchStatus) {
          // Top banner: background refetch or offline indicator
          final banner = switch (fetchStatus) {
            FetchStatus.fetching => const _StatusBanner(icon: Icons.sync, label: 'Updating…', color: Colors.blue),
            FetchStatus.paused => const _StatusBanner(
              icon: Icons.wifi_off,
              label: 'Offline — showing cached data',
              color: Colors.orange,
            ),
            FetchStatus.idle => const SizedBox.shrink(),
          };

          return switch (state) {
            // ── First load (no cache) ───────────────────────────────────────
            Initial() || Loading(previousData: null) => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading users…')],
              ),
            ),

            // ── Hard error (no cache) ───────────────────────────────────────
            Failure(:final error, previousData: null) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load users\n$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: () => context.qora.invalidateWhere((key) => key.firstOrNull == 'users'),
                    ),
                  ],
                ),
              ),
            ),

            // ── Data available (Success / Loading with cache / Failure with cache) ──
            _ => Column(
              children: [
                banner,
                // Soft error banner when refresh fails but old data is still shown
                if (state is Failure<List<User>>) _ErrorBanner(error: state.error),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      context.qora.invalidateWhere((key) => key.firstOrNull == 'users');
                      await Future<void>.delayed(const Duration(milliseconds: 300));
                    },
                    child: ListView.builder(
                      itemCount: state.dataOrNull?.length ?? 0,
                      itemBuilder: (context, index) {
                        final user = state.dataOrNull![index];
                        return _UserTile(
                          user: user,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(builder: (_) => UserDetailScreen(userId: user.id)),
                          ),
                        );
                      },
                    ),
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

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final MaterialColor color;

  const _StatusBanner({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: color.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color.shade700),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color.shade700)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final Object error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: Colors.red.shade50,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Refresh failed: $error', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final User user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(child: Text(user.avatar, style: const TextStyle(fontSize: 22))),
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(user.email),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
