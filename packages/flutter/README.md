# qora_flutter

<a href="https://pub.dev/packages/qora_flutter"><img src="https://img.shields.io/pub/v/qora_flutter.svg" alt="pub.dev"></a>
<a href="https://github.com/meragix/qora/actions/workflows/flutter.yml"><img src="https://img.shields.io/github/actions/workflow/status/meragix/qora/flutter.yml?branch=main&label=ci" alt="CI"></a>
<a href="https://pub.dev/packages/qora_flutter/score"><img src="https://img.shields.io/pub/likes/qora_flutter" alt="likes"></a>
<a href="https://pub.dev/packages/qora_flutter/score"><img src="https://img.shields.io/pub/points/qora_flutter" alt="pub points"></a>

Flutter integration for [Qora](https://pub.dev/packages/qora). Bind server state to your UI with a single widget: no `setState`, no `StreamBuilder`, no loading flag boilerplate.

Part of the [Qora monorepo](https://github.com/meragix/qora).

## Features

| Feature | Description |
|---------|-------------|
| Declarative UI | Access your data directly via `QoraBuilder` |
| Lifecycle aware | Queries pause when the app is in the background |
| Network aware | Triggers refetches when the connection is restored |
| Zero boilerplate | Loading, error, and data states handled in one place |

## Install

```yaml
dependencies:
  qora_flutter: ^1.2.0
```

`qora_flutter` automatically includes `qora` and `connectivity_plus` as dependencies; no extra packages needed.

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
  fetcher: () => api.getUser(userId),
  builder: (context, state, fetchStatus) => switch (state) {
    Loading(:final previousData) => previousData != null
        ? UserCard(user: previousData, isRefreshing: true)
        : const CircularProgressIndicator(),
    Success(:final data) => UserCard(user: data),
    Failure(:final error, :final previousData) => ErrorScreen(
        message: error.toString(),
        onRetry: () => context.qora.invalidate(['users', userId]),
      ),
    _ => const SizedBox.shrink(),
  },
)
```

## Invalidate after a mutation

```dart
await api.createPost(payload);
context.qora.invalidate(['posts']);
context.qora.invalidateWhere((k) => k.firstOrNull == 'posts');
```

Every `QoraBuilder` subscribed to a matching key re-fetches automatically.

## Optimistic updates

```dart
final client = context.qora;
final key = ['users', userId];

final snapshot = client.getState<User>(key);

client.setQueryData<User>(key, user.copyWith(name: newName));

try {
  final updated = await api.updateUser(userId, newName);
  client.setQueryData<User>(key, updated);
} catch (_) {
  client.restoreQueryData<User>(key, snapshot);
}
```

## Observe without fetching

`QoraStateBuilder<T>` mirrors a query's state without triggering a fetch; ideal for badges, counters, or secondary displays:

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
