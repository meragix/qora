<br />
<div align="center">
  <a href="https://github.com/meragix/qora">
    <img src="assets/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">Qora</h3>

  <p align="center">
    Server state for Flutter apps that have to keep working offline.
    <br />
    <a href="https://qora.meragix.dev"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/meragix/qora/tree/main/examples">Examples</a>
    &middot;
    <a href="https://github.com/meragix/qora/issues/new">Report a bug</a>
    &middot;
    <a href="https://github.com/meragix/qora/issues/new">Ask a question</a>
  </p>

  <div align="center">
    <a href="https://pub.dev/packages/qora_flutter"><img src="https://img.shields.io/pub/v/qora_flutter.svg?label=qora_flutter" alt="qora_flutter"></a>
    <a href="https://github.com/meragix/qora/actions/workflows/dart.yml"><img src="https://img.shields.io/github/actions/workflow/status/meragix/qora/dart.yml?branch=main&label=ci" alt="CI"></a>
    <a href="https://pub.dev/packages/qora/score"><img src="https://img.shields.io/pub/points/qora" alt="pub points"></a>
    <a href="LICENSE"><img src="https://img.shields.io/github/license/meragix/qora" alt="license"></a>
  </div>
</div>
<br />

Qora fetches, caches and synchronizes server data in Flutter, and keeps your app usable when the network is not. Cached data is saved to disk and shown on the next cold start, queries pause while the device is offline and resume on reconnect, and writes made offline are queued and replayed in order.

If you know [TanStack Query](https://tanstack.com/query), you already know the model: server data is a cache with a lifecycle, not global UI state. Qora brings that model to Dart 3 with sealed classes and pattern matching, and no code generation.

## Why Qora

- **Offline is built in, not bolted on.** Disk persistence, connectivity-aware query pausing and an offline mutation queue with optimistic results are part of the core, wired by one widget.
- **States you can match exhaustively.** `QoraState` (`Initial`, `Loading`, `Success`, `Failure`) is a sealed class, and every non-initial state keeps the previous data, so a refetch or an error never blanks the screen.
- **You can see what the cache is doing.** The in-app DevTools overlay shows every query, its state, its staleness and the pending mutations while you run the app.
- **It does not replace your state management.** Keep Riverpod, BLoC or Provider for UI state; Qora owns server data. Integration guides cover each of them.

## Quick start

```yaml
dependencies:
  qora_flutter: ^1.3.1
```

Create a client and put it above your app. `QoraScope.auto` wires app-lifecycle and connectivity tracking for you:

```dart
void main() {
  final client = QoraClient();

  runApp(QoraScope.auto(client: client, child: const MyApp()));
}
```

Bind a query to the widget tree:

```dart
QoraBuilder<User>(
  queryKey: ['users', userId],
  fetcher: () => api.getUser(userId),
  builder: (context, state, fetchStatus) {
    final user = state.dataOrNull; // kept across refetches and errors
    return Column(children: [
      if (fetchStatus == FetchStatus.paused) const Text('Offline, showing saved data'),
      if (user != null) UserCard(user),
      if (state case Loading(previousData: null)) const CircularProgressIndicator(),
      if (state case Failure(:final error)) ErrorBanner(error),
    ]);
  },
)
```

Ten widgets watching `['users', userId]` share one cache entry and one network call. Calling `client.invalidate(['users', userId])` refetches every mounted subscriber.

## Offline in practice

### Show saved data on a cold start

Swap `QoraClient` for `PersistQoraClient` and register a serializer per type. Successful fetches are written to storage; `hydrate()` restores them before the first frame. Stale entries are shown immediately, then revalidated in the background.

```dart
final storage = InMemoryStorageAdapter(); // implement StorageAdapter for Hive, Isar, SharedPreferences...
final client = PersistQoraClient(
  storage: storage,
  persistDuration: const Duration(days: 7),
);
client.registerSerializer<User>(
  QoraSerializer(toJson: (u) => u.toJson(), fromJson: User.fromJson),
  name: 'User', // stable name, safe with --obfuscate and on the web
);
await storage.init();
await client.hydrate();
```

### Write while offline

With `offlineQueue: true`, a mutation triggered offline returns an optimistic result right away and is replayed when the device reconnects. Queries listed in `invalidates` refetch after the real server response.

```dart
QoraMutationBuilder<Comment, String, void>(
  mutator: (text) => api.postComment(text),
  options: MutationOptions(
    offlineQueue: true,
    optimisticResponse: (text) => Comment.draft(text),
    invalidates: [['comments']],
  ),
  builder: (context, state, mutate) => switch (state) {
    MutationSuccess(:final data, :final isOptimistic) => ListTile(
        title: Text(data.text),
        trailing: isOptimistic ? const Icon(Icons.schedule) : null, // not synced yet
      ),
    MutationFailure(:final error) => ErrorBanner(error),
    _ => TextButton(
        onPressed: state.isPending ? null : () => mutate('Nice post'),
        child: const Text('Send'),
      ),
  },
)
```

`context.qora.pendingOfflineMutations` exposes the queue, for a "3 changes waiting to sync" badge.

**Current limit:** the offline mutation queue lives in memory. It survives connectivity changes, not an app restart. Persisting it is the next milestone; see the [roadmap](ROADMAP.md).

## Pure Dart

The core package has no Flutter dependency and works in CLIs, servers and tests:

```dart
final user = await client.fetchQuery<User>(
  key: ['users', userId],
  fetcher: () => api.getUser(userId),
  options: const QoraOptions(staleTime: Duration(minutes: 5)),
);
```

## Features

| | |
|---|---|
| Stale-while-revalidate | Cached data renders on the first frame, fresh data replaces it in the background |
| Request deduplication | Concurrent fetches for the same key share one in-flight request |
| Invalidation | By exact key, by key prefix, by predicate, or by tag (`QueryTag('post')`) |
| Optimistic updates | `onMutate` / `onError` rollback, or `optimisticResponse` for offline writes |
| Retries | Exponential backoff with a custom retry condition |
| Lifecycle aware | Refetch on app resume and on reconnect, configurable per query |
| Infinite queries | Cursor or page based, with a `maxPages` memory window |
| Dependent queries | `dependsOn` waits for another key to have data |
| Hooks | `useQuery`, `useMutation`, `useInfiniteQuery`, `useFetchStatus` via `qora_hooks` |
| Zero code generation | No `build_runner`, no annotations |

## Is Qora the right tool?

- **You use Riverpod or BLoC and fetch data in providers or cubits.** Qora can sit next to them and take over caching, refetching and invalidation. See the [Riverpod](https://qora.meragix.dev/en/third-party/with-riverpod) and [BLoC](https://qora.meragix.dev/en/third-party/with-bloc) guides.
- **You are coming from `cached_query` or `flutter_query`.** The [migration guide](https://qora.meragix.dev/en/getting-started/migrating-from-other-libraries) maps each API to its Qora equivalent.
- **Your app is read-only and always online.** A plain `FutureBuilder` or your existing state management may be enough. Qora pays off when the same data is shown in several places, changes after writes, or must survive bad connectivity.

## Packages

| Package | Version | Description |
|---------|---------|-------------|
| [qora](packages/dart) | [![pub](https://img.shields.io/pub/v/qora.svg?label=)](https://pub.dev/packages/qora) | Pure Dart core: cache, queries, mutations, persistence |
| [qora_flutter](packages/flutter) | [![pub](https://img.shields.io/pub/v/qora_flutter.svg?label=)](https://pub.dev/packages/qora_flutter) | Widgets, lifecycle and connectivity managers |
| [qora_hooks](packages/hooks) | [![pub](https://img.shields.io/pub/v/qora_hooks.svg?label=)](https://pub.dev/packages/qora_hooks) | `flutter_hooks` API |
| [qora_devtools_overlay](packages/devtools/overlay) | [![pub](https://img.shields.io/pub/v/qora_devtools_overlay.svg?label=)](https://pub.dev/packages/qora_devtools_overlay) | In-app debug panel |

## DevTools overlay

```bash
flutter pub add qora_devtools_overlay
```

```dart
void main() {
  final tracker = OverlayTracker();
  // No tracker in release: the client falls back to NoOpTracker.
  final client = QoraClient(tracker: kDebugMode ? tracker : null);

  runApp(
    QoraInspector(
      tracker: tracker,
      client: kDebugMode ? client : null,
      child: QoraScope.auto(client: client, child: const MyApp()),
    ),
  );
}
```

`QoraInspector` builds nothing in release builds, and tree shaking removes the panel. A Flutter DevTools extension sharing the same event protocol is in development and not published yet.

## Documentation

Guides, recipes and API reference: **[qora.meragix.dev](https://qora.meragix.dev)**

- [Quick start](https://qora.meragix.dev/en/getting-started/quick-start)
- [Offline-first example](https://qora.meragix.dev/en/examples/offline-first)
- [Persistence](https://qora.meragix.dev/en/recipes/persistence)
- [Network status](https://qora.meragix.dev/en/flutter-integration/network-status)
- [Coming from TanStack Query](https://qora.meragix.dev/en/getting-started/coming-from-tanstack-query)

Runnable apps live in [examples/](examples).

### Using an AI assistant

Assistants tend to write TanStack Query code with Dart syntax. Add [`qora-rules.md`](https://qora.meragix.dev/qora-rules.md) to your project's `CLAUDE.md`, `AGENTS.md` or Cursor rules, and point the assistant at [`llms.txt`](https://qora.meragix.dev/llms.txt). See [AI Assistants](https://qora.meragix.dev/en/getting-started/ai-assistants).

## Contributing

Issues and questions are welcome, including "I tried it and it did not fit". See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and [ROADMAP.md](ROADMAP.md) for what is next.

## License

MIT, see [LICENSE](LICENSE).
