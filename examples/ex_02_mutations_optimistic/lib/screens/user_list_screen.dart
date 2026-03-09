import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import '../models/user.dart';
import '../services/fake_api.dart';
import 'rename_user_sheet.dart';

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
            onPressed: () =>
                context.qora.invalidateWhere((key) => key.firstOrNull == 'users'),
          ),
        ],
      ),
      body: QoraBuilder<List<User>>(
        queryKey: const ['users'],
        fetcher: FakeApi.getUsers,
        options: const QoraOptions(
          staleTime: Duration(minutes: 5),
          cacheTime: Duration(minutes: 10),
        ),
        builder: (context, state, fetchStatus) {
          final banner = switch (fetchStatus) {
            FetchStatus.fetching => const _StatusBanner(
                icon: Icons.sync,
                label: 'Updating…',
                color: Colors.blue,
              ),
            FetchStatus.paused => const _StatusBanner(
                icon: Icons.wifi_off,
                label: 'Offline — showing cached data',
                color: Colors.orange,
              ),
            FetchStatus.idle => const SizedBox.shrink(),
          };

          return switch (state) {
            // First load with no cache
            Initial() || Loading(previousData: null) => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading users…'),
                  ],
                ),
              ),

            // Hard error with no cached data
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
                        onPressed: () => context.qora
                            .invalidateWhere((key) => key.firstOrNull == 'users'),
                      ),
                    ],
                  ),
                ),
              ),

            // Data available: Success, Loading(data), or Failure(data)
            _ => Column(
                children: [
                  banner,
                  if (state is Failure<List<User>>)
                    _ErrorBanner(error: state.error),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.dataOrNull?.length ?? 0,
                      itemBuilder: (context, index) {
                        final user = state.dataOrNull![index];
                        return _UserTile(
                          user: user,
                          onEdit: () => _showRenameSheet(context, user),
                        );
                      },
                    ),
                  ),
                ],
              ),
          };
        },
      ),
    );
  }

  Future<void> _showRenameSheet(BuildContext context, User user) {
    // Capture the client before the sheet opens: modal routes run in a
    // separate navigator overlay and may not resolve QoraScope on their own.
    final client = context.qora;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RenameUserSheet(user: user, client: client),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final User user;
  final VoidCallback onEdit;

  const _UserTile({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(user.avatar, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(user.email),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Rename',
          onPressed: onEdit,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final MaterialColor color;

  const _StatusBanner({
    required this.icon,
    required this.label,
    required this.color,
  });

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
            child: Text(
              'Refresh failed: $error',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
