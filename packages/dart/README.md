# qora

<a href="https://pub.dev/packages/qora"><img src="https://img.shields.io/pub/v/qora.svg" alt="pub.dev"></a>
<a href="https://github.com/meragix/qora/actions/workflows/dart.yml"><img src="https://img.shields.io/github/actions/workflow/status/meragix/qora/dart.yml?branch=main&label=ci" alt="CI"></a>
<a href="https://pub.dev/packages/qora/score"><img src="https://img.shields.io/pub/likes/qora" alt="likes"></a>
<a href="https://pub.dev/packages/qora/score"><img src="https://img.shields.io/pub/points/qora" alt="pub points"></a>

Pure Dart server-state management that works in Flutter apps, CLI tools, backend services, and shared packages.

Part of the [Qora monorepo](https://github.com/meragix/qora). For Flutter-specific features, see [qora_flutter](https://pub.dev/packages/qora_flutter).

## Install

```yaml
dependencies:
  qora: ^1.0.0
```

## Quick start

### Fetch and cache

```dart
import 'package:qora/qora.dart';

final client = QoraClient(
  config: const QoraClientConfig(
    defaultOptions: QoraOptions(
      staleTime: Duration(minutes: 5),
      retryCount: 3,
    ),
  ),
);

final user = await client.fetchQuery<User>(
  key: ['users', 1],
  fetcher: () => api.getUser(1),
);
```

### Watch state reactively

```dart
client.watchQuery<User>(
  key: ['users', 1],
  fetcher: () => api.getUser(1),
).listen((state) {
  switch (state) {
    case Success(:final data):  print('User: ${data.name}');
    case Failure(:final error): print('Error: $error');
    default: {}
  }
});
```

### Optimistic update with rollback

```dart
final snapshot = client.getState<User>(['users', 1]);
client.setQueryData(['users', 1], user.copyWith(name: 'Alice'));
try {
  await api.updateUser(1, name: 'Alice');
} catch (_) {
  client.restoreQueryData(['users', 1], snapshot);
}
```

Don't forget to dispose the client when it's no longer needed:

```dart
client.dispose();
```

## State machine

`QoraState<T>` is a sealed class. The Dart compiler enforces exhaustive handling:

```dart
switch (state) {
  case Initial(): // Not yet fetched
  case Loading(:final previousData): // Fetching; previousData available during revalidation
  case Success(:final data, :final updatedAt): // Fresh data
  case Failure(:final error, :final previousData): // Error; previousData available for fallback
}
```

## Documentation

Full guides and API reference: **[qora.meragix.dev](https://qora.meragix.dev)**
