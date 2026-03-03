# qora_flutter

Flutter integration for [Qora](https://pub.dev/packages/qora). Bind server state to your UI with a single widget: no `setState`, no `StreamBuilder`, and no loading flag spaghetti.

Qora handles the complex plumbing of asynchronous data: caching, background refetching, and offline persistence. Your UI simply reacts to the state.

## Features

* **Declarative UI**: Access your data directly via `QoraBuilder`.
* **Lifecycle Aware**: Queries are automatically paused when the app is in the background.
* **Network Aware**: Triggers refetches automatically when the connection is restored.
* **Zero Boilerplate**: Manage loading, error, and data states in one place.

## Install

```yaml
dependencies:
  qora_flutter: ^1.0.0
```

> `qora_flutter` automatically includes `qora` and `connectivity_plus` as dependencies — no extra packages needed.

## Setup

Wrap your app with `QoraScope` once:

```dart
import 'package:qora_flutter/qora_flutter.dart';

void main() {
  final client = QoraClient(
    config: const QoraClientConfig(debugMode: kDebugMode),
  );

  runApp(
    QoraScope(
      client: client,
      // Optional: refetch when app resumes or network reconnects
      lifecycleManager: FlutterLifecycleManager(qoraClient: client),
      connectivityManager: FlutterConnectivityManager(),
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
  builder: (context, state, fetchStatus) {
    return state.when(
      onInitial: () => const SizedBox.shrink(),
      onLoading: (previousData) => previousData != null
          ? UserCard(user: previousData, isRefreshing: true)
          : const CircularProgressIndicator(),
      onSuccess: (user, updatedAt) => UserCard(user: user),
      onFailure: (error, _, previousData) => ErrorScreen(
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

* [Setup](https://qora.meragix.dev/flutter-integration/setup)
* [QoraScope](https://qora.meragix.dev/flutter-integration/qora-scope)
* [QoraBuilder](https://qora.meragix.dev/flutter-integration/qora-builder)
* [Optimistic Updates](https://qora.meragix.dev/guides/optimistic-updates)
