// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_qora/flutter_qora.dart';
import 'package:qora_hooks/qora_hooks.dart';

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

void main() {
  final client = QoraClient(
    config: const QoraClientConfig(
      defaultOptions: QoraOptions(
        staleTime: Duration(minutes: 5),
        retryCount: 3,
      ),
    ),
  );

  runApp(
    QoraScope(
      client: client,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'qora_hooks Demo',
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('qora_hooks')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('useQuery — user list'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const UserListScreen()),
          ),
          ListTile(
            title: const Text('useMutation — edit profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const EditProfileScreen()),
          ),
          ListTile(
            title: const Text('useInfiniteQuery — paginated posts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const PostsScreen()),
          ),
          ListTile(
            title: const Text('Composing hooks — profile + update'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const ProfileScreen(userId: 1)),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

// ---------------------------------------------------------------------------
// Example 1 — useQuery: fetch + all four states
// ---------------------------------------------------------------------------

class UserListScreen extends HookWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // useQuery triggers a fetch on mount and rebuilds on every state change.
    // The initial value is read from the cache synchronously — no loading
    // flash when navigating back to this screen.
    final state = useQuery<List<User>>(
      key: const ['users'],
      fetcher: ApiService.getUsers,
      options: const QoraOptions(staleTime: Duration(minutes: 2)),
    );

    final client = useQueryClient();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            // Manually invalidate so the next render triggers a background
            // revalidation while showing the stale list (SWR).
            onPressed: () => client.invalidate(const ['users']),
          ),
        ],
      ),
      body: switch (state) {
        Initial() => const Center(child: Text('Loading…')),
        Loading(:final previousData) when previousData != null => Stack(
            children: [
              _UserListView(users: previousData),
              const LinearProgressIndicator(),
            ],
          ),
        Loading() => const Center(child: CircularProgressIndicator()),
        Success(:final data) => data.isEmpty
            ? const Center(child: Text('No users'))
            : _UserListView(users: data),
        Failure(:final error) => _ErrorView(
            message: '$error',
            onRetry: () => client.invalidate(const ['users']),
          ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Example 2 — useMutation: fire-and-forget + optimistic invalidation
// ---------------------------------------------------------------------------

class EditProfileScreen extends HookWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nameController = useTextEditingController(text: 'Alice');
    final client = useQueryClient();

    // useMutation creates a MutationController once and disposes it on unmount.
    final mutation = useMutation<User, String>(
      mutator: (name) => ApiService.updateUser(42, name),
      options: MutationOptions(
        onSuccess: (user, _, __) async {
          // Invalidate the user query so it re-fetches with the new name.
          client.invalidate(['users', user.id]);
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),

            // Show error banner when mutation fails.
            if (mutation.isError)
              _ErrorBanner(message: '${mutation.error}'),

            // Show success message.
            if (mutation.isSuccess)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Saved: ${mutation.data?.name}',
                  style: const TextStyle(color: Colors.green),
                ),
              ),

            FilledButton(
              onPressed: mutation.isPending
                  ? null
                  : () => mutation.mutate(nameController.text),
              child: mutation.isPending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),

            if (!mutation.isIdle)
              TextButton(
                onPressed: mutation.reset,
                child: const Text('Reset'),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Example 3 — useInfiniteQuery: scroll-to-load pagination
// ---------------------------------------------------------------------------

class PostsScreen extends HookWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final query = useInfiniteQuery<PostsPage, int>(
      key: const ['posts'],
      fetcher: ApiService.getPosts,
      getNextPageParam: (page) => page.hasMore ? page.nextCursor : null,
      initialPageParam: 0,
    );

    final allPosts = query.pages.expand((p) => p.items).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Posts')),
      body: switch ((query.isLoading, query.pages.isEmpty)) {
        (true, _) => const Center(child: CircularProgressIndicator()),
        (_, true) => const Center(child: Text('No posts')),
        _ => ListView.builder(
            itemCount: allPosts.length + (query.hasNextPage ? 1 : 0),
            itemBuilder: (context, i) {
              // When the sentinel tile scrolls into view, fetch the next page.
              if (i == allPosts.length) {
                if (!query.isFetchingNextPage) query.fetchNextPage();
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return ListTile(
                leading: CircleAvatar(child: Text('${allPosts[i].id}')),
                title: Text(allPosts[i].title),
              );
            },
          ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Example 4 — Composing hooks: query + mutation in one widget
// ---------------------------------------------------------------------------

class ProfileScreen extends HookWidget {
  final int userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();

    final userState = useQuery<User>(
      key: ['users', userId],
      fetcher: () => ApiService.getUser(userId),
    );

    final updateMutation = useMutation<User, String>(
      mutator: (name) => ApiService.updateUser(userId, name),
      options: MutationOptions(
        onSuccess: (user, _, __) async {
          client.invalidate(['users', userId]);
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: switch (userState) {
        Initial() || Loading(previousData: null) =>
          const Center(child: CircularProgressIndicator()),
        Loading(:final previousData?) =>
          _ProfileBody(user: previousData, mutation: updateMutation),
        Success(:final data) =>
          _ProfileBody(user: data, mutation: updateMutation),
        Failure(:final error) => _ErrorView(
            message: '$error',
            onRetry: () => client.invalidate(['users', userId]),
          ),
      },
    );
  }
}

class _ProfileBody extends HookWidget {
  final User user;
  final MutationHandle<User, String> mutation;

  const _ProfileBody({required this.user, required this.mutation});

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: user.name);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CircleAvatar(
            radius: 40,
            child: Text(user.name[0].toUpperCase()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          if (mutation.isError)
            _ErrorBanner(message: '${mutation.error}'),
          FilledButton(
            onPressed: mutation.isPending
                ? null
                : () => mutation.mutate(controller.text),
            child: mutation.isPending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
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

  const User({required this.id, required this.name, required this.email});
}

class Post {
  final int id;
  final String title;

  const Post({required this.id, required this.title});
}

class PostsPage {
  final List<Post> items;
  final int nextCursor;
  final bool hasMore;

  const PostsPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });
}

abstract class ApiService {
  static Future<List<User>> getUsers() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return List.generate(
      12,
      (i) => User(id: i + 1, name: 'User ${i + 1}', email: 'u${i + 1}@x.com'),
    );
  }

  static Future<User> getUser(int id) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return User(id: id, name: 'User $id', email: 'u$id@x.com');
  }

  static Future<User> updateUser(int id, String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return User(id: id, name: name, email: 'u$id@x.com');
  }

  static Future<PostsPage> getPosts(int cursor) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    const pageSize = 10;
    final items = List.generate(
      pageSize,
      (i) => Post(id: cursor + i + 1, title: 'Post ${cursor + i + 1}'),
    );
    return PostsPage(
      items: items,
      nextCursor: cursor + pageSize,
      hasMore: cursor < 30,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared UI helpers
// ---------------------------------------------------------------------------

class _UserListView extends StatelessWidget {
  final List<User> users;

  const _UserListView({required this.users});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (_, i) => ListTile(
        leading: CircleAvatar(child: Text(users[i].name[0])),
        title: Text(users[i].name),
        subtitle: Text(users[i].email),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ColoredBox(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
