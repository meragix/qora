# Roadmap

Qora's direction: be the server-state layer you pick when a Flutter app has to keep working on a bad network. Every milestone is judged against that goal first. Priorities move with feedback: open an [issue](https://github.com/meragix/qora/issues/new) if something blocks you.

## Shipped

### v1.0: Foundation

- Query engine with stale-while-revalidate and request deduplication
- Two-axis state model (`QoraState` and `FetchStatus`)
- `QoraBuilder`, `QoraMutationBuilder`, `InfiniteQueryBuilder` and hooks
- Offline mutation queue with FIFO replay (in memory)
- `PersistQoraClient` with obfuscation-safe serialization
- Cancellation (`CancelToken`), retry policy, polling (`refetchInterval`)
- Conditional and dependent fetching (`enabled`, `dependsOn`)
- In-app DevTools overlay

### v1.1: Stability

- `onBackgroundFetchError`; background fetch errors no longer escape the zone
- Obfuscation-safe serializer registration enforced in release builds

### v1.2: Cache intelligence

- Structural sharing and `keepPreviousData`
- Tag-based invalidation (`providesTags`, `invalidatesTags`)
- `transform` / `transformError` pipeline
- Automatic invalidation after mutations (`MutationOptions.invalidates`)

### v1.3: Correctness and developer experience

- Active watchers refetch after any invalidation; fixed a refetch loop in `QoraBuilder`
- Cached data renders on the first frame
- `QoraScope.auto()`, `initialData` / `placeholderData`, `select` rebuild filter
- `invalidatePrefix`, `useFetchStatus`
- Guides: route prefetching, Dio, GraphQL, migration from `cached_query` and `flutter_query`

## Next: v1.4, offline all the way

| Feature | Why |
|---|---|
| **Persisted offline mutation queue** | Today a write queued offline is lost if the app is killed before reconnecting. Closures cannot be persisted, so mutations will be registered by name with a serializer for their variables, and the queue will store `(name, variables)` through the existing `StorageAdapter`. |
| **First-party storage adapters** | Ship ready-made `StorageAdapter` implementations (Hive, SharedPreferences) so persistence takes three lines instead of a custom class. |
| **Sync status API** | A stream and a hook (`useOfflineQueue`) exposing pending, replaying and failed mutations, for "3 changes waiting to sync" UIs without polling. |
| **Replay conflict handling** | A per-mutation callback to decide what happens when a replayed write is rejected (for example HTTP 409): drop, retry, or surface to the user. |
| **Offline demo app on the web** | A live demo where you can toggle the network and watch the cache, the queue and the overlay react. |

## Later

| Feature | Notes |
|---|---|
| **Typed selector widget** | `QoraSelector<T, R>` that hands the builder the selected value directly, instead of using `select` only as a rebuild filter. |
| **Stream watcher** | `client.watchStream(key, stream)` to pipe WebSocket or Firestore data into the cache. |
| **Flutter DevTools extension** | Publish the IDE extension that shares the overlay's event protocol. |
| **Dart server adapter** | The core is pure Dart; a `shelf` integration would make it usable for server-side caching. |

## How priorities are decided

1. **Adoption friction:** what stops someone from shipping Qora in production
2. **User feedback:** issues and pull requests
3. **Differentiation:** does it make Qora the obvious choice for offline-capable apps
4. **Maintenance cost:** can it be built without becoming a burden

Disagree with an item, or missing one? Open an issue or a pull request against this file.
