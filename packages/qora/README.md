# qora

Pure Dart server state management. Zero Flutter dependency — works in Flutter apps, CLI tools, backend services, or shared packages.

## Install

```yaml
dependencies:
  qora: ^1.0.0
```

## Quick start

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

// One-shot fetch — cached, deduplicated, retried automatically
final user = await client.fetchQuery<User>(
  key: ['users', 1],
  fetcher: () => api.getUser(1),
);

// Reactive stream — emits on every state transition
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

// Optimistic update with safe rollback
final snapshot = client.getState<User>(['users', 1]);
client.setQueryData(['users', 1], user.copyWith(name: 'Alice'));
try {
  await api.updateUser(1, name: 'Alice');
} catch (_) {
  client.restoreQueryData(['users', 1], snapshot);
}

client.dispose();
```

## State machine

`QoraState<T>` is a sealed class — the Dart compiler enforces exhaustive handling:

```dart
switch (state) {
  case Initial():                        // Not yet fetched
  case Loading(:final previousData):    // Fetching; previousData available during revalidation
  case Success(:final data, :final updatedAt): // Fresh data
  case Failure(:final error, :final previousData): // Error; previousData available for fallback
}
```

## Documentation

Full guides and API reference: **[qora.meragix.com](https://qora.meragix.com)**


_github-pages-challenge-donfreddy.qora.meragix.dev