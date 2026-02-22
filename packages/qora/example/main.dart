// ignore_for_file: avoid_print

import 'package:qora/qora.dart';

// ---------------------------------------------------------------------------
// Fake data models
// ---------------------------------------------------------------------------

class User {
  final int id;
  final String name;
  final String email;

  const User({required this.id, required this.name, required this.email});

  User copyWith({String? name, String? email}) => User(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
      );

  @override
  String toString() => 'User(id: $id, name: $name, email: $email)';
}

class Post {
  final int id;
  final String title;

  const Post({required this.id, required this.title});

  @override
  String toString() => 'Post(id: $id, title: $title)';
}

// ---------------------------------------------------------------------------
// Fake API — simulates network latency
// ---------------------------------------------------------------------------

class Api {
  static Future<User> getUser(int id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return User(id: id, name: 'Alice', email: 'alice@example.com');
  }

  static Future<User> updateUser(int id, String newName) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return User(id: id, name: newName, email: 'alice@example.com');
  }

  static Future<List<Post>> getPosts() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return [
      const Post(id: 1, title: 'Hello Qora'),
      const Post(id: 2, title: 'SWR is great'),
    ];
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

Future<void> main() async {
  // ── 1. Create the client ─────────────────────────────────────────────────

  final client = QoraClient(
    config: QoraClientConfig(
      defaultOptions: const QoraOptions(
        staleTime: Duration(minutes: 5),
        cacheTime: Duration(minutes: 10),
        retryCount: 2,
      ),
      debugMode: false, // set to true to see cache logs
      errorMapper: (error, stackTrace) => QoraException(
        'Network error: $error',
        originalError: error,
        stackTrace: stackTrace,
      ),
    ),
  );

  // ── 2. One-shot fetch (caching + deduplication + retry) ──────────────────

  // First call — cache miss, hits the network.
  final user = await client.fetchQuery<User>(
    key: ['users', 1],
    fetcher: () => Api.getUser(1),
  );
  print('Fetched: $user');

  // Second call — cache hit (fresh), returns immediately without network.
  final cached = await client.fetchQuery<User>(
    key: ['users', 1],
    fetcher: () => Api.getUser(1),
  );
  print('From cache: $cached');

  // ── 3. Reactive stream (watchQuery) ──────────────────────────────────────

  // watchQuery auto-fetches on first subscription and emits every transition.
  final subscription = client.watchQuery<List<Post>>(
    key: ['posts'],
    fetcher: Api.getPosts,
    options: const QoraOptions(staleTime: Duration(seconds: 30)),
  ).listen((state) {
    switch (state) {
      case Initial():
        print('Posts: not started');
      case Loading(:final previousData):
        final label =
            previousData != null ? '${previousData.length} stale' : 'none';
        print('Posts: loading (previous: $label)');
      case Success(:final data):
        print('Posts: ${data.length} loaded');
      case Failure(:final error):
        print('Posts: error — $error');
    }
  });

  // Let the first fetch complete.
  await Future<void>.delayed(const Duration(milliseconds: 200));
  await subscription.cancel();

  // ── 4. Observe-only stream (watchState) ──────────────────────────────────

  // watchState subscribes to the state stream without triggering any fetch.
  // Ideal for badge counters or derived UI components.
  final observe = client.watchState<User>(['users', 1]).listen((state) {
    if (state case Success(:final data)) {
      print('Observer sees: ${data.name}');
    }
  });

  // ── 5. Optimistic update ──────────────────────────────────────────────────

  // a) Take a snapshot of current data for rollback.
  final snapshot = client.getQueryData<User>(['users', 1]);

  // b) Update the cache immediately — all active streams see this at once.
  client.setQueryData<User>(
    ['users', 1],
    snapshot!.copyWith(name: 'Alice (saving…)'),
  );

  try {
    // c) Confirm with the real server response.
    final updated = await Api.updateUser(1, 'Alice Smith');
    client.setQueryData<User>(['users', 1], updated);

    // d) Invalidate related queries (e.g. a user list).
    client.invalidateWhere((key) => key.firstOrNull == 'users');
  } catch (_) {
    // e) Roll back to the original snapshot on failure.
    client.restoreQueryData<User>(['users', 1], snapshot);
  }

  await observe.cancel();

  // ── 6. Prefetch (pre-warm cache before navigation) ────────────────────────

  await client.prefetch<User>(
    key: ['users', 2],
    fetcher: () => Api.getUser(2),
  );
  print('Prefetched user 2');

  // ── 7. Cache inspection ───────────────────────────────────────────────────

  print('Cached keys: ${client.cachedKeys.toList()}');
  print('Debug info: ${client.debugInfo()}');

  // ── 8. Read full state ────────────────────────────────────────────────────

  final state = client.getQueryState<User>(['users', 1]);
  switch (state) {
    case Success(:final data, :final updatedAt):
      final age = DateTime.now().difference(updatedAt);
      print('User ${data.name}, age: ${age.inMilliseconds} ms');
    case Failure(:final error):
      print('Error: $error');
    default:
      print('No data yet');
  }

  // ── 9. Invalidate a single query ─────────────────────────────────────────

  client.invalidate(['posts']);

  // ── 10. Remove from cache & dispose ──────────────────────────────────────

  client.removeQuery(['users', 2]);
  client.dispose();

  print('Done.');
}
