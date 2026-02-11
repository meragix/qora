# qora

The core engine of the Qora ecosystem. A pure Dart library for managing server state with zero dependencies on the Flutter framework.

## Features

- **Agnostic Architecture**: Works with any HTTP client (Dio, http) and any storage (Hive, Isar).
- **Concurrency Management**: Prevents multiple simultaneous calls to the same endpoint.
- **Persistence Layer**: Abstract `ReqryStorage` interface for custom caching strategies.

## Installation

```yaml
dependencies:
  qora: ^0.1.0

## Quick Start (Logic Layer)

```dart
final qora = QoraClient();

// Define a query
final profile = await qora.fetchQuery<User>(
  key: QoraKey(['user', 1]),
  fetcher: (signal) => api.getUser(1, cancelToken: signal),
  decoder: (json) => User.fromJson(json),
  staleTime: Duration(minutes: 5),
);
```

## Architecture Trade-offs

- **Pros**: Zero Flutter dependency. Can be used in CLI or Server-side Dart.
- **Cons**: Requires manual state observation if used without flutter_qora.

## Documentation

For full documentation, examples, and API reference, please visit our [Documentation Site](https://meragix.github.io/qora).
