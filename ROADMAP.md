# Roadmap

This document outlines the planned direction for Qora. It's a living document: priorities shift based on feedback, adoption, and community contributions.

**Legend:** 🚀 Planned | 💡 Proposal | 👥 Community-driven | 🤔 Under consideration

---

## ✅ v1.0 - Foundation

- Core query engine with stale-while-revalidate semantics
- Two-axis state model (`QoraState` + `FetchStatus`)
- `QoraBuilder` / `QoraConsumer` / `useQora` (hooks)
- Offline mutation queue with FIFO replay
- `PersistQoraClient` with obfuscation-safe serialization
- Infinite queries with `maxPages` memory window
- Flutter DevTools overlay (in-app inspector)
- Zero code generation, pure Dart 3 sealed classes + pattern matching
- 7 production-grade example apps

---

## 🚀 v1.1 - Tooling & Robustness

*High-confidence items: building these regardless of community signal.*

| Feature | Rationale |
|---|---|
| **Query cancellation** | `QoraOptions.cancelOnDispose`: cancel in-flight fetches when the last widget unsubscribes. Prevents ghost updates and wasted bandwidth. |
| **Retry policy API** | Configurable retry count, delay, backoff multiplier, and optional `retryCondition` callback. Currently uses hardcoded exponential backoff. |
| **Mutation → auto-invalidation** | `QoraMutationOptions(invalidates: [QueryKey])`: automatically refetch related queries on mutation success. The #1 workflow gap today. |
| **Tag-based invalidation** | `QoraOptions(providesTags: [PostTag.list])` / `QoraMutationOptions(invalidatesTags: [PostTag.list])`: automatic, granular cache invalidation via tags instead of manual key targeting. Inspired by RTK Query's providesTags/invalidatesTags. Lets you write "this mutation invalidates all 'Post' queries" without knowing their exact keys. |
| **Transformation pipeline** | `QoraOptions(transform: (data) => ...)` and `transformError`: clean data transformation at the option level, separate from the fetcher. More testable and composable than transforming inside the fetcher callback. |
| **Structural sharing** | Preserve referential equality for unchanged nested data across fetches. If only `updatedAt` changes, `data.name` reference stays the same. Prevents unnecessary widget rebuilds in deeply nested UIs. Core feature of TanStack Query v5. |
| **gcTime (garbage collection)** | `QoraOptions(gcTime: Duration(minutes: 5))`: separate duration from `staleTime` that controls how long inactive query data stays in cache before eviction. Prevents unbounded cache growth without forcing users to manage manual cleanup. |
| **refreshInterval (polling)** | `QoraOptions(refreshInterval: Duration(seconds: 30))`: automatic periodic refetching for dashboards, live feeds, and status indicators. Common pattern from SWR and TanStack Query. |
| **Conditional fetching** | When `queryKey` is null or a sentinel value, skip the fetch entirely. Enables dependent queries: "wait for user ID, then fetch posts." Standard in SWR/TanStack Query, trivial in Qora. |

---

## 💡 v1.2 - Developer Experience

*High-value, medium effort: will build pending feedback.*

| Feature | Rationale |
|---|---|
| **fallbackData / initial data** | Seed the cache with placeholder or SSR data before any fetch completes. Enables instant renders and server-side hydration without waiting. Modeled after SWR's `fallbackData` and TanStack Query's `initialData`. |
| **Global mutate / setQueryData** | Expose a top-level `QoraScope.of(context).mutate(key, data)` pattern that lets any widget update cache without a fetcher. Enables optimistic updates from anywhere, inspired by SWR's global `mutate()`. |
| **isValidating vs isLoading** | Give users a clearer API to distinguish "first load with no data" (`isLoading`) from "background refetch with stale data" (`isValidating`). Already supported internally via `FetchStatus`, but not surfaced cleanly in the builder API. |
| **One-call refetch triggers** | `QoraScope.auto()` that activates lifecycle + connectivity listeners by default, similar to RTK Query's `setupListeners()`. Currently requires manually wiring `FlutterLifecycleManager` and `FlutterConnectivityManager`. |
| **Route-level prefetching** | Guide + snippet showing how to call `qoraClient.prefetchQuery()` in GoRouter redirects or AutoRoute resolvers. Data is in cache before the screen mounts. |
| **Stream/WebSocket watcher** | `client.watchStream(key, stream)`: lightweight utility to pipe a real-time stream into the cache via `setQueryData`. No heavy reconnect logic, brings your own stream. |
| **select (derived data)** | `QoraBuilder(select: (data) => data.items.length)`: subscribe to a computed subset of query data and rebuild only when that subset changes. Inspired by TanStack Query's `select` option. Ideal for badges, counters, summaries. |
| **Prefix key matching** | `client.invalidate(prefix: ['posts'])` matching all keys starting with `['posts']`: `['posts']`, `['posts', '1']`, `['posts', '2']`. More natural than `invalidateWhere((k) => k.first == 'posts')`. Modeled after TanStack Query's prefix matching. |
| **keepPreviousData for paginated queries** | `QoraOptions(keepPreviousData: true)`: keep the last successful page data visible while fetching the next one. Already supported for infinite queries, but not for simple offset-based pagination with `fetchQuery`. |
| **Query dependencies** | Declare that query A depends on query B: invalidating B also refetches A. Solves cross-cutting cache relationships without manual wiring. |

---

## 👥 Ecosystem & Guides

*Documentation and examples, not packages. PRs welcome.*

| Guide | What it covers |
|---|---|
| **Dio integration** | Mapping `DioException` to `QoraFailure`, attaching Qora to Dio interceptors, token refresh patterns |
| **GraphQL clients** | Wrapping `graphql` or `ferry` packages in a Qora `fetcher`, custom cache interop notes |
| **GoRouter / AutoRoute** | Route-level prefetching patterns (see v1.2) |
| **Migration from flutter_query** | Side-by-side API comparison and migration steps |
| **Migration from cached_query** | Side-by-side API comparison, key differences (SWR, previousData, offline queue) |
| **Riverpod interop** | How to expose Qora queries as Riverpod providers for incremental adoption |

---

## 🤔 Stretch Goals

*Ideas that need more community traction, time, or architectural groundwork.*

| Idea | Notes |
|---|---|
| **Time-travel debugging** | Snapshot cache history in DevTools, rewind/replay mutations. Extremely high engineering cost - requires full cache diffing + persistence |
| **Plugin system** | Official `QoraPlugin` base class with lifecycle hooks (`onQueryStart`, `onCacheWrite`, etc). Enables analytics, logging, sentry breadcrumbs. Only makes sense once there are 3+ external plugins |
| **Type-safe query keys** | Code-gen or builder pattern for `QueryKey` with auto-complete. Critique: Qora intentionally avoids code-gen. Would need strong community demand to reconsider |

---

## How priorities are decided

1. **User feedback**: issues, discussions, and PRs are the primary signal
2. **Adoption friction**: what stops someone from using Qora in production
3. **Competitive differentiation**: features that make Qora the obvious choice over alternatives
4. **Maintenance cost**: can this be implemented without becoming a maintenance burden

**Have an opinion?** Open a [discussion](https://github.com/meragix/qora/discussions) or submit a PR against this file.
