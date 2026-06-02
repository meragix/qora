# Roadmap

This document outlines the planned direction for Qora. Priorities shift based on feedback, adoption, and community contributions.

**Legend:** 🚀 Planned | 💡 Proposal | 👥 Community-driven | 🤔 Under consideration

> **Timeline:** v1.x releases target every 4-6 weeks. Items move between milestones based on community signal.

---

## ✅ v1.0: Foundation *(shipped)*

- Core query engine with stale-while-revalidate semantics
- Two-axis state model (`QoraState` + `FetchStatus`)
- `QoraBuilder`, `QoraConsumer`, `useQora` (hooks)
- Offline mutation queue with FIFO replay
- `PersistQoraClient` with obfuscation-safe serialization
- Infinite queries with `maxPages` memory window
- Flutter DevTools overlay (in-app inspector)
- Zero code generation, pure Dart 3 sealed classes + pattern matching
- 7 production-grade example apps

---

## 🚀 v1.1: Core & Performance *(next 4 weeks)*

*High-confidence items built regardless of community signal.*

| Feature | Rationale |
|---|---|
| **Query cancellation** | Cancel in-flight fetches when the last subscriber disposes. Prevents ghost updates and wasted bandwidth. |
| **Retry policy API** | Expose configurable retry count, delay, backoff multiplier, and `retryCondition` callback. Currently hardcoded. |
| **Mutation → auto-invalidation** | Automatically refetch queries affected by a mutation with `QoraMutationOptions(invalidates: [QueryKey])`. The #1 workflow gap today. |
| **Conditional fetching** | Skip fetch when `queryKey` is null. Enables dependent queries: "wait for user ID, then fetch posts." |
| **Polling (refreshInterval)** | `QoraOptions(refreshInterval: Duration(seconds: 30))`. Automatic periodic refetch for dashboards and live feeds. |

---

## 🚀 v1.2: Cache Intelligence *(next 8 weeks)*

*Core cache improvements for production-grade apps.*

| Feature | Rationale |
|---|---|
| **Structural sharing** | Preserve referential equality for unchanged nested data across fetches. Prevents unnecessary widget rebuilds in deeply nested UIs. |
| **gcTime (garbage collection)** | Separate duration from `staleTime` that controls cache retention for inactive queries. Prevents unbounded memory growth. |
| **Tag-based invalidation** | Decouple invalidation from query keys. Mutations declare tags they invalidate; queries declare tags they provide. Inspired by RTK Query. |
| **Transformation pipeline** | `QoraOptions(transform: (data) => ...)` and `transformError`. Clean data transformation separate from the fetcher. More testable and composable. |
| **keepPreviousData for pagination** | Keep the last page data visible while the next page loads. Already supported for infinite queries; missing for offset-based pagination. |

---

## 💡 v1.3: Developer Experience *(next 12 weeks)*

*High-value ergonomic improvements. Priority may shift based on feedback.*

| Feature | Rationale |
|---|---|
| **fallbackData / initial data** | Seed the cache with placeholder or SSR data before any fetch. Enables instant renders and server-side hydration. |
| **Global mutate API** | `context.qora.mutate(key, data)` from any widget, no fetcher required. Enables optimistic updates from anywhere. |
| **isValidating vs isLoading** | Surface the existing `FetchStatus` distinction in the builder API. `isLoading` = no data yet; `isValidating` = background refresh with stale data visible. |
| **select (derived data)** | `QoraBuilder(select: (data) => data.items.length)`. Subscribe to a computed subset and rebuild only when it changes. |
| **Prefix key matching** | `client.invalidate(prefix: ['posts'])` matches all keys starting with `['posts']`. More intuitive than predicate callbacks. |
| **One-call refetch triggers** | `QoraScope.auto()` enables lifecycle and connectivity listeners by default. Currently requires manual wiring of `FlutterLifecycleManager` and `FlutterConnectivityManager`. |
| **Route-level prefetching** | Guide + snippet for GoRouter redirects and AutoRoute resolvers. Data loads before the screen mounts. |
| **Stream/WebSocket watcher** | `client.watchStream(key, stream)`. Lightweight utility to pipe real-time data into the cache via `setQueryData`. |
| **Query dependencies** | Declare that query A depends on query B. Invalidating B refetches A automatically. |

---

## 👥 Ecosystem & Guides

*Documentation and examples, not packages. PRs welcome.*

| Guide | What it covers |
|---|---|
| **Dio integration** | Mapping `DioException` to `QoraFailure`, interceptors, token refresh patterns |
| **GraphQL clients** | Wrapping `graphql` or `ferry` in a Qora fetcher |
| **GoRouter / AutoRoute** | Route-level prefetching patterns |
| **Migration from flutter_query** | Side-by-side API comparison |
| **Migration from cached_query** | Key differences: SWR, previousData, offline queue |
| **Riverpod interop** | Exposing Qora queries as Riverpod providers |

---

## 🤔 Stretch Goals

*Ideas requiring community traction, time, or architectural groundwork.*

| Idea | Notes |
|---|---|
| **Time-travel debugging** | Snapshot cache history in DevTools, rewind and replay mutations. High engineering cost. Revisit at 1k+ GitHub stars. |
| **Plugin system** | `QoraPlugin` base class with lifecycle hooks (`onQueryStart`, `onCacheWrite`). Only viable with 3+ external plugin requests. |
| **Type-safe query keys** | Code-gen or builder pattern for auto-completed `QueryKey`. Conflicts with Qora's zero-code-gen principle. Would need strong community demand. |
| **Dart server-side adapter** | Core engine is already pure Dart. Needs `dart:io` HTTP adapter and shelf integration. Niche but valuable for server-driven caching. |

---
go
## How priorities are decided

1. **User feedback:** issues, discussions, and PRs are the primary signal
2. **Adoption friction:** what stops someone from using Qora in production
3. **Competitive differentiation:** features that make Qora the obvious choice
4. **Maintenance cost:** can this be implemented without becoming a burden

**Have an opinion?** Open a [discussion](https://github.com/meragix/qora/discussions) or submit a PR against this file.
