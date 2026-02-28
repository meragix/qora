# flutter_qora

Flutter widgets for [Qora](https://pub.dev/packages/qora) — bind server state to your UI with a single widget. No `setState`, no `StreamBuilder`, no loading flag spaghetti.

## Install

```yaml
dependencies:
  flutter_qora: ^1.0.0
```

> `flutter_qora` automatically includes `qora` and `connectivity_plus` as dependencies — no extra packages needed.

## Setup

Wrap your app with `QoraScope` once:

```dart
import 'package:flutter_qora/flutter_qora.dart';

void main() {
  final client = QoraClient(
    config: const QoraClientConfig(debugMode: kDebugMode),
  );

  runApp(
    QoraScope(
      client: client,
      // Optional: refetch when app resumes or network reconnects
      lifecycleManager: FlutterLifecycleManager(qoraClient: client),
      connectivityManager: FlutterConnectivityManager(qoraClient: client),
      child: const MyApp(),
    ),
  );
}
```

## Fetch and display data

`QoraBuilder<T>` fetches on mount, caches the result, and rebuilds on every state change:

```dart
QoraBuilder<User>(
  queryKey: ['users', userId],
  queryFn: () => api.getUser(userId),
  builder: (context, state) {
    return state.when(
      onInitial: () => const SizedBox.shrink(),
      onLoading: (previousData) => previousData != null
          ? UserCard(user: previousData, isRefreshing: true)
          : const CircularProgressIndicator(),
      onSuccess: (user, updatedAt) => UserCard(user: user),
      onError: (error, _, previousData) => ErrorScreen(
        message: error.toString(),
        onRetry: () => context.qora.invalidate(['users', userId]),
      ),
    );
  },
)
```

## Invalidate after a mutation

```dart
// In a button handler, after creating or updating data
await api.createPost(payload);
context.qora.invalidate(['posts']);              // Exact key
context.qora.invalidateWhere((k) => k.firstOrNull == 'posts'); // By predicate
```

Every `QoraBuilder` subscribed to a matching key re-fetches automatically.

## Optimistic updates

```dart
final client = context.qora;
final key = ['users', userId];

// 1. Snapshot for rollback
final snapshot = client.getState<User>(key);

// 2. Update UI instantly
client.setQueryData<User>(key, user.copyWith(name: newName));

try {
  // 3. Fire the mutation
  final updated = await api.updateUser(userId, newName);
  client.setQueryData<User>(key, updated); // Confirm with server data
} catch (_) {
  // 4. Roll back on failure
  client.restoreQueryData<User>(key, snapshot);
}
```

## Observe without fetching

`QoraStateBuilder<T>` mirrors a query's state without triggering a fetch — ideal for badges, counters, or secondary displays:

```dart
QoraStateBuilder<List<Notification>>(
  queryKey: ['notifications'],
  builder: (context, state) {
    final count = state.dataOrNull?.length ?? 0;
    return Badge(label: Text('$count'), child: const Icon(Icons.notifications));
  },
)
```

## Documentation

Full guides and API reference: **[qora.meragix.dev](https://qora.meragix.dev)**

- [Setup](https://qora.meragix.dev/flutter-integration/setup)
- [QoraScope](https://qora.meragix.dev/flutter-integration/qora-scope)
- [QoraBuilder](https://qora.meragix.dev/flutter-integration/qora-builder)
- [Optimistic Updates](https://qora.meragix.dev/guides/optimistic-updates)
