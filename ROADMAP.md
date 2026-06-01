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

---

## 💡 v1.2 - Developer Experience

*High-value, medium effort: will build pending feedback.*

| Feature | Rationale |
|---|---|
| **Route-level prefetching** | Guide + snippet showing how to call `qoraClient.prefetchQuery()` in GoRouter redirects or AutoRoute resolvers. Data is in cache before the screen mounts. |
| **Stream/WebSocket watcher** | `client.watchStream(key, stream)`: lightweight utility to pipe a real-time stream into the cache via `setQueryData`. No heavy reconnect logic, brings your own stream. |
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
