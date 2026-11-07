# Qora rules for AI coding assistants

Qora (pub.dev: `qora`, `qora_flutter`, `qora_hooks`) is a server-state library for Flutter and Dart, version 1.3. It is inspired by TanStack Query but its API is different: do not translate TanStack or React Query code literally. Full docs: https://qora.meragix.dev/llms.txt

## Setup

- Flutter apps depend on `qora_flutter` only; it re-exports `qora`. Import `package:qora_flutter/qora_flutter.dart`, not `package:qora/qora.dart`.
- With `flutter_hooks`, also depend on `qora_hooks` and import `package:qora_hooks/qora_hooks.dart`.
- Create one `QoraClient` per app and wrap the app with `QoraScope.auto`, which also refetches on resume and pauses queries offline.
- `kDebugMode` needs `import 'package:flutter/foundation.dart';`.
- No code generation, no build_runner.

```dart
final client = QoraClient(
  config: QoraClientConfig(
    defaultOptions: const QoraOptions(staleTime: Duration(minutes: 5)),
    debugMode: kDebugMode,
  ),
);
runApp(QoraScope.auto(client: client, child: const MyApp()));
```

## Reading data

- Widget: `QoraBuilder<T>(queryKey: [...], fetcher: () => ..., builder: (context, state, fetchStatus) => ...)`.
- Hook: `final state = useQuery<T>(key: [...], fetcher: () => ...);` returns a `QoraState<T>` directly.
- Keys are lists: `['users']`, `['users', id]`. The key is the cache address.
- A fetcher must throw on failure. Returning `null` or swallowing the error is treated as a success.
- `QoraState<T>` is a sealed class: `Initial`, `Loading(previousData)`, `Success(data)`, `Failure(error, previousData)`. Render it with an exhaustive `switch`, and keep showing `previousData` during refetches and errors:

```dart
builder: (context, state, fetchStatus) => switch (state) {
  Success(:final data) => UserList(data),
  Loading(:final previousData?) => UserList(previousData),
  Failure(:final previousData?) => UserList(previousData),
  Failure(:final error) => ErrorView(error),
  _ => const CircularProgressIndicator(),
},
```

- `state.dataOrNull` returns the data of `Success`, or the `previousData` of `Loading` and `Failure`.
- `fetchStatus` is a separate axis: `FetchStatus.fetching`, `FetchStatus.paused` (offline, waiting) or `FetchStatus.idle`.

## Offline

- Queries do not fail offline: they pause. In the default `NetworkMode.online`, the state becomes `Loading(previousData: <cached or null>)` and `fetchStatus` becomes `FetchStatus.paused`.
- Offline with nothing cached is `Loading` with `previousData == null` plus `FetchStatus.paused`, never `Initial`. Detect it with `state.dataOrNull == null && fetchStatus == FetchStatus.paused`.
- `NetworkMode.offlineFirst` keeps a cached `Success` while paused. `NetworkMode.always` fetches anyway.
- Writes are queued offline only with `MutationOptions(offlineQueue: true)`. The queue is in memory in 1.3: it does not survive an app restart.
- To keep cached data across restarts, use `PersistQoraClient` with a `StorageAdapter`, register a `QoraSerializer` per type with an explicit `name` (it throws without one), and `await client.hydrate()` before `runApp`.

## Writing data

- Widget: `QoraMutationBuilder<TData, TVariables, TContext>(mutator: ..., options: MutationOptions(...), builder: (context, state, mutate) => ...)`.
- Hook: `final m = useMutation<TData, TVariables>(mutator: ..., options: ...);` then `m.mutate(vars)` or `await m.mutateAsync(vars)`. Its rollback context type is `void`; use `QoraMutationBuilder` when `onMutate` must return a snapshot for `onError`.
- Callback order: `onMutate`, mutator, then `onSuccess`, `invalidates`, `invalidatesTags`, `onSettled`; or `onError`, `onSettled`.
- Optimistic update: in `onMutate`, read with `client.getQueryData<T>(key)`, write with `client.setQueryData<T>(key, value)`, return the previous value; in `onError`, call `client.restoreQueryData<T>(key, previous)`.
- Imperative access in widgets: `context.qora` returns the `QoraClient`.

## Invalidation

- `client.invalidate(key)` and `MutationOptions(invalidates: [...])` match the exact key only: `['todos']` does not invalidate `['todos', 1]`.
- For a family of keys, use `client.invalidatePrefix(['todos'])` or tags (`QoraOptions(providesTags: ...)` with `MutationOptions(invalidatesTags: ...)`).

## Do not write

| Wrong (TanStack or other libraries) | Qora |
| --- | --- |
| `useQuery(queryKey: ..., queryFn: ...)` | `useQuery(key: ..., fetcher: ...)` |
| `QoraBuilder(queryKey: ..., queryFn: ...)` | `QoraBuilder(queryKey: ..., fetcher: ...)` |
| `cacheTime` | `gcTime` |
| `state.when(data: ..., loading: ..., error: ...)` | an exhaustive `switch` (`maybeWhen` and `fold` also exist; `when` does not) |
| `if (state.isLoading) spinner` with no `previousData` handling | `switch` with `Loading(:final previousData?)` |
| `queryClient.invalidateQueries(['todos'])` to hit `['todos', 1]` | `client.invalidatePrefix(['todos'])` |
| `client.getState(key)`, `client.getQueryDataOrNull(...)` | `client.getQueryData<T>(key)` for the data, `client.getQueryState<T>(key)` for the state |
| `select` to transform the data passed to the builder | `select` only filters rebuilds; transform with `QoraOptions(transform: ...)` or `state.mapData(...)` |
| `mapSuccess`, `debounceLoading` | `mapData`, `delayLoading` |
| Checking `state is Initial` to detect offline | `state.dataOrNull == null && fetchStatus == FetchStatus.paused` |
| `qora_devtools_overlay` under `dev_dependencies` | under `dependencies`; it builds nothing in release |
| `qora_devtools_extension` | not published; use `qora_devtools_overlay` |
