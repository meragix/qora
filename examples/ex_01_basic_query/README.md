# ex\_01\_basic\_query

Learn the fundamentals of Qora: setup, `QoraBuilder`, stale-while-revalidate, `FetchStatus`, and per-item queries.

<!-- ![Demo](screenshots/demo.gif) -->

## What This Demonstrates

- `QoraScope` + `FlutterLifecycleManager` + `FlutterConnectivityManager` setup
- `QoraBuilder` with the 3-arg builder `(context, state, fetchStatus)`
- `switch (state)` pattern matching on the `QoraState` sealed class
- Stale-while-revalidate: instant load from cache on re-navigation
- `FetchStatus.fetching` banner during background revalidation
- `FetchStatus.paused` offline indicator
- Graceful degradation via `Loading.previousData` / `Failure.previousData`
- Pull-to-refresh via `invalidateWhere`
- Per-item query with `updatedAt` timestamp (`User Detail` screen)

## Running

```bash
cd examples/ex_01_basic_query
flutter pub get
flutter run
```

## Key Concepts

### 1. Setup

```dart
final qoraClient = QoraClient(
  config: const QoraClientConfig(
    defaultOptions: QoraOptions(
      staleTime: Duration(minutes: 5),
      cacheTime: Duration(minutes: 10),
    ),
    debugMode: kDebugMode,
  ),
);

runApp(
  QoraScope(
    client: qoraClient,
    lifecycleManager: FlutterLifecycleManager(qoraClient: qoraClient),
    connectivityManager: FlutterConnectivityManager(),
    child: const MyApp(),
  ),
);
```

### 2. QoraBuilder — list query

```dart
QoraBuilder<List<User>>(
  queryKey: const ['users'],
  queryFn: FakeApi.getUsers,
  builder: (context, state, fetchStatus) {
    final banner = switch (fetchStatus) {
      FetchStatus.fetching => const _StatusBanner('Updating…'),
      FetchStatus.paused   => const _StatusBanner('Offline'),
      FetchStatus.idle     => const SizedBox.shrink(),
    };

    return switch (state) {
      Initial() || Loading(previousData: null) => const CircularProgressIndicator(),
      Failure(:final error, previousData: null) => ErrorWidget('$error'),
      _ => Column(children: [
          banner,
          if (state is Failure<List<User>>) ErrorBanner(state.error),
          Expanded(child: UserListView(users: state.dataOrNull!)),
        ]),
    };
  },
)
```

### 3. Per-item query

Each user detail screen uses its own cache key:

```dart
QoraBuilder<User>(
  queryKey: ['users', userId],
  queryFn: () => FakeApi.getUser(userId),
  options: const QoraOptions(staleTime: Duration(minutes: 5)),
  builder: (context, state, fetchStatus) { ... },
)
```

Navigate back and forward — the second visit loads instantly from cache.

### 4. Invalidate & Refetch

```dart
// Refetch one query
context.qora.invalidate(['users', userId]);

// Refetch all queries under a namespace
context.qora.invalidateWhere((key) => key.firstOrNull == 'users');
```

## Project Structure

```
lib/
├── main.dart                       # QoraScope + FlutterLifecycleManager setup
├── screens/
│   ├── user_list_screen.dart       # List query, FetchStatus banners, pull-to-refresh
│   └── user_detail_screen.dart     # Per-item query, updatedAt, graceful degradation
├── models/
│   └── user.dart                   # User model
└── services/
    └── fake_api.dart               # Simulated API with 2 s latency and random failures
```

## Try This

1. Open **User List** — wait 2 s for initial load
2. Go back, reopen — **instant load from cache**
3. Pull to refresh — see stale data + "Updating…" banner simultaneously
4. Open a user, go back, reopen — instant from its own `['users', id]` key
5. Hit the refresh icon while offline — see the "Offline" banner (requires disabling network)
6. Wait 5 minutes — `staleTime` expires, next open triggers silent background refetch

## Stale-While-Revalidate

```text
Open screen
  │
  ├─ Cache HIT + fresh  →  show data immediately, no fetch
  ├─ Cache HIT + stale  →  show data immediately, fetch in background
  │                         FetchStatus: fetching → idle
  └─ Cache MISS         →  Loading → Success / Failure
```

## Next Steps

- [`ex_02_mutations`](../ex_02_mutations) — optimistic updates and rollback
- [`ex_03_infinite_scroll`](../ex_03_infinite_scroll) — `InfiniteQueryBuilder` and pagination

## Questions?

- [Documentation](../../docs)
- [GitHub Issues](https://github.com/meragix/qora/issues)
