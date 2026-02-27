import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../lib/flutter_qora.dart';

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

void main() {
  final client = QoraClient(
    config: QoraClientConfig(
      defaultOptions: const QoraOptions(
        staleTime: Duration(minutes: 5),
        cacheTime: Duration(minutes: 10),
        retryCount: 3,
      ),
      debugMode: kDebugMode,
      errorMapper: (error, stackTrace) => QoraException(
        error.toString().contains('401') ? 'Unauthorized' : 'Network error',
        originalError: error,
        stackTrace: stackTrace,
      ),
    ),
  );

  runApp(
    QoraScope(
      client: client,
      // Invalidates all queries when the app resumes after 30 s in background.
      lifecycleManager: FlutterLifecycleManager(
        qoraClient: client,
        refetchInterval: const Duration(seconds: 30),
      ),
      // Invalidates all queries when the device reconnects after being offline.
      connectivityManager: FlutterConnectivityManager(qoraClient: client),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Qora Flutter Demo',
      home: UserListScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Example 1 — Basic list with all four states
// ---------------------------------------------------------------------------

class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            // Invalidate all "users" queries — QoraBuilder detects the
            // resulting Loading(previousData: ...) and re-fetches automatically.
            onPressed: () => context.qora.invalidateWhere(
              (key) => key.firstOrNull == 'users',
            ),
          ),
        ],
      ),
      body: QoraBuilder<List<User>>(
        queryKey: const ['users'],
        queryFn: ApiService.getUsers,
        builder: (context, state) {
          return switch (state) {
            Initial() => const Center(child: Text('Press refresh to load')),
            Loading(:final previousData) => previousData != null
                ? Stack(children: [
                    UserListView(users: previousData),
                    const LinearProgressIndicator(),
                  ])
                : const Center(child: CircularProgressIndicator()),
            Success(:final data) => data.isEmpty
                ? const Center(child: Text('No users found'))
                : UserListView(users: data),
            Failure(:final error, :final previousData) => Column(
                children: [
                  if (previousData != null)
                    Expanded(child: UserListView(users: previousData)),
                  ErrorBanner(message: '$error'),
                ],
              ),
          };
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Example 2 — Flicker-free pagination with keepPreviousData
// ---------------------------------------------------------------------------

class PaginatedUsersScreen extends StatefulWidget {
  const PaginatedUsersScreen({super.key});

  @override
  State<PaginatedUsersScreen> createState() => _PaginatedUsersScreenState();
}

class _PaginatedUsersScreenState extends State<PaginatedUsersScreen> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users — paginated')),
      body: Column(
        children: [
          Expanded(
            child: QoraBuilder<List<User>>(
              queryKey: ['users', 'page', _page],
              queryFn: () => ApiService.getUsersPaged(_page),
              // Keep the previous page visible while the next page loads.
              keepPreviousData: true,
              builder: (context, state) {
                // dataOrNull returns Success.data OR Loading/Failure.previousData.
                final users = state.dataOrNull ?? [];
                return Stack(
                  children: [
                    UserListView(users: users),
                    if (state.isLoading)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(),
                      ),
                  ],
                );
              },
            ),
          ),
          _PaginationControls(
            page: _page,
            onPrev: _page > 1 ? () => setState(() => _page--) : null,
            onNext: () => setState(() => _page++),
          ),
        ],
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  final int page;
  final VoidCallback? onPrev;
  final VoidCallback onNext;

  const _PaginationControls({
    required this.page,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
        Text('Page $page'),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Example 3 — Detail screen with manual refresh
// ---------------------------------------------------------------------------

class UserDetailScreen extends StatelessWidget {
  final int userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.qora.invalidate(['users', userId]),
          ),
        ],
      ),
      body: QoraBuilder<User>(
        queryKey: ['users', userId],
        queryFn: () => ApiService.getUser(userId),
        builder: (context, state) {
          return switch (state) {
            Initial() || Loading(previousData: null) => const Center(
                child: CircularProgressIndicator(),
              ),
            Loading(:final previousData?) => UserDetailView(
                user: previousData,
                isRefreshing: true,
              ),
            Success(:final data, :final updatedAt) => UserDetailView(
                user: data,
                updatedAt: updatedAt,
              ),
            Failure(:final error, previousData: null) => _ErrorScreen(
                message: '$error',
                onRetry: () => context.qora.invalidate(['users', userId]),
              ),
            Failure(:final error, :final previousData?) => Column(
                children: [
                  Expanded(child: UserDetailView(user: previousData)),
                  ErrorBanner(message: '$error'),
                ],
              ),
          };
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Example 4 — QoraStateBuilder: observe without fetching
// ---------------------------------------------------------------------------

/// Shows the user avatar wherever it is needed in the tree, without
/// triggering a second fetch — the data is owned by [UserDetailScreen].
class UserAvatarWidget extends StatelessWidget {
  final int userId;

  const UserAvatarWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return QoraStateBuilder<User>(
      queryKey: ['users', userId],
      builder: (context, state) {
        return switch (state) {
          Success(:final data) => CircleAvatar(
              backgroundImage: NetworkImage(data.avatarUrl),
            ),
          Loading() => const CircleAvatar(child: CircularProgressIndicator()),
          _ => const CircleAvatar(child: Icon(Icons.person)),
        };
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Example 5 — Optimistic update
// ---------------------------------------------------------------------------

class UpdateUserButton extends StatelessWidget {
  final int userId;
  final String newName;

  const UpdateUserButton({
    super.key,
    required this.userId,
    required this.newName,
  });

  Future<void> _update(BuildContext context) async {
    final client = context.qora;
    final key = ['users', userId];

    // 1. Snapshot current data for potential rollback.
    final snapshot = client.getQueryData<User>(key);

    // 2. Optimistic update — UI reflects the change immediately.
    if (snapshot != null) {
      client.setQueryData<User>(key, snapshot.copyWith(name: newName));
    }

    try {
      // 3. Confirm with the real server response.
      final updated = await ApiService.updateUser(userId, newName);
      client.setQueryData<User>(key, updated);

      // 4. Invalidate the user list so it reflects the new name.
      client.invalidateWhere((k) => k.firstOrNull == 'users' && k.length == 1);
    } catch (error) {
      // 5. Roll back on failure.
      client.restoreQueryData<User>(key, snapshot);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _update(context),
      child: const Text('Save'),
    );
  }
}

// ---------------------------------------------------------------------------
// Example 6 — Conditional (dependent) query
// ---------------------------------------------------------------------------

class ConditionalQueryWidget extends StatefulWidget {
  const ConditionalQueryWidget({super.key});

  @override
  State<ConditionalQueryWidget> createState() => _ConditionalQueryWidgetState();
}

class _ConditionalQueryWidgetState extends State<ConditionalQueryWidget> {
  bool _enabled = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Enable query'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        QoraBuilder<String>(
          queryKey: const ['conditional'],
          queryFn: ApiService.getData,
          enabled: _enabled,
          builder: (context, state) => ListTile(
            title: Text('State: ${state.runtimeType}'),
            subtitle: state is Success<String> ? Text(state.data) : null,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fake models and API
// ---------------------------------------------------------------------------

class User {
  final int id;
  final String name;
  final String email;
  final String avatarUrl;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  User copyWith({String? name, String? email}) => User(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        avatarUrl: avatarUrl,
      );
}

class ApiService {
  static Future<List<User>> getUsers() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return List.generate(
      10,
      (i) => User(
        id: i,
        name: 'User $i',
        email: 'user$i@example.com',
        avatarUrl: 'https://i.pravatar.cc/150?img=$i',
      ),
    );
  }

  static Future<List<User>> getUsersPaged(int page) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final offset = (page - 1) * 10;
    return List.generate(
      10,
      (i) => User(
        id: offset + i,
        name: 'User ${offset + i}',
        email: 'user${offset + i}@example.com',
        avatarUrl: 'https://i.pravatar.cc/150?img=${offset + i}',
      ),
    );
  }

  static Future<User> getUser(int id) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return User(
      id: id,
      name: 'User $id',
      email: 'user$id@example.com',
      avatarUrl: 'https://i.pravatar.cc/150?img=$id',
    );
  }

  static Future<User> updateUser(int id, String newName) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return User(
      id: id,
      name: newName,
      email: 'user$id@example.com',
      avatarUrl: 'https://i.pravatar.cc/150?img=$id',
    );
  }

  static Future<String> getData() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return 'Some data';
  }
}

// ---------------------------------------------------------------------------
// Shared UI widgets
// ---------------------------------------------------------------------------

class UserListView extends StatelessWidget {
  final List<User> users;

  const UserListView({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, i) {
        final user = users[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(user.avatarUrl),
          ),
          title: Text(user.name),
          subtitle: Text(user.email),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => UserDetailScreen(userId: user.id),
            ),
          ),
        );
      },
    );
  }
}

class UserDetailView extends StatelessWidget {
  final User user;
  final bool isRefreshing;
  final DateTime? updatedAt;

  const UserDetailView({
    super.key,
    required this.user,
    this.isRefreshing = false,
    this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRefreshing) const LinearProgressIndicator(),
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(user.avatarUrl),
            ),
          ),
          const SizedBox(height: 16),
          Text(user.name, style: Theme.of(context).textTheme.headlineMedium),
          Text(user.email),
          if (updatedAt != null)
            Text(
              'Updated: ${updatedAt!.toLocal()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.red.shade100,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
