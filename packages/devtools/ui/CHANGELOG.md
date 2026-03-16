<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.3.0] - 2026-03-16

### Added

- `VmServiceClient` protocol handshake — on `connect()`, calls `ext.qora.getVersion` and stores the result in `remoteProtocolVersion`; `isProtocolCompatible` returns `false` when the remote major version differs from the UI's expected major version, enabling a compatibility warning banner. Gracefully falls back to `null` / compatible for legacy runtimes that pre-date `0.3.0`.
- `DependencyNotifier.dependsOnEdges` — `List<DependsOnEdge>` of authoritative query→query dependency edges sourced from `QueryEvent.dependsOnKey`; populated in a new `_onEvent` branch for `QueryEvent.fetched` events that carry a non-null `dependsOnKey`. No temporal heuristic involved.
- `DependsOnEdge` — value class with `dependencyKey` (the upstream query) and `dependentKey` (the downstream query); distinct from `GraphEdge` (mutation→query heuristic).

### Changed

- `DependencyNotifier` retains the existing 500 ms mutation→query heuristic (`GraphEdge`) for edges not expressed via `dependsOn`; `dependsOnEdges` is the authoritative complement, not a replacement.
- `DependencyNotifier.clear()` now also clears `_dependsOnEdges`.

## [0.2.0] - 2026-03-02

### Added

- **Query Inspector (live)** — `CacheInspectorScreen` rebuilt with a real-time query list driven by live `QueryEvent`s; includes a filter bar, summary strip, and per-row Refetch / Invalidate actions with an expandable JSON data preview.
- **`QueriesNotifier`** — new granular update methods: `addQuery`, `updateQuery`, `removeQuery`; enables in-place list mutations without full snapshot replacement.
- **`CacheController`** — now subscribes to live events via `ObserveEventsUseCase` (in addition to snapshot polling via Refresh); dispatches `addQuery` / `updateQuery` / `removeQuery` to `QueriesNotifier` on each incoming `QueryEvent`.
- **`JsonTreeViewer`** widget — recursive expand/collapse JSON renderer with syntax highlighting (string=teal, number=blue, bool=amber, null=grey) and a depth limit of 5 to prevent runaway nesting.
- **`QueryRow`** widget — displays key breadcrumb chips, color-coded status badge, size pill, last-updated timestamp, Refetch / Invalidate action buttons, and an expandable `JsonTreeViewer`; supports lazy payload loading via `FetchLargePayloadUseCase`.
- **Network Activity Monitor** — new `NetworkActivityNotifier` tracking active (in-flight) and recent (completed, capped at 100) fetches with stats getters (`totalRequests`, `avgDurationMs`, `errorRate`); new `NetworkActivityScreen` with a stats strip, active-fetch spinner list, and a recent-fetch data table.
- **Performance Metrics** — new `PerformanceNotifier` accumulating per-key stats (fetch count, total duration ms, error count, last active timestamp) from `QueryEvent.fetched`; new `PerformanceScreen` with four summary cards and a `DataTable` sortable by fetches, avg duration, errors, or last active.
- **Query Dependency Graph** — new `DependencyNotifier` inferring mutation→query edges from a 500 ms correlation window between `MutationEvent.settled` and `QueryEvent.invalidated`; new `DependencyGraphScreen` with `InteractiveViewer` + `CustomPainter` graph (mutations=red, queries=blue, Bézier arrows), tap-to-select node detail panel, and key filter — no external dependencies.
- **Data Diff tab** — `DataDiffTab` implemented: BEFORE (mutation variables) and AFTER (result) side-by-side columns for the most recent settled mutation, powered by `TimelineController` and rendered with `JsonTreeViewer`.
- **AppShell** expanded to 6 tabs: QUERIES, MUTATIONS, INSPECTOR, NETWORK, PERFORMANCE, GRAPH.

## [0.1.0] - 2026-02-28

### Added

- Initial implementation of Qora DevTools Flutter Web extension UI.
- Added VM service client integration:
  - extension event listening (`qora:event`),
  - typed event decoding via `qora_devtools_shared`,
  - command dispatch to `ext.qora.*`.
- Added repository layer:
  - `EventRepository` and `PayloadRepository` contracts,
  - runtime-backed implementations for command/event/payload operations.
- Added domain use-cases:
  - observe runtime events,
  - refetch query command,
  - fetch large payload by chunk metadata.
- Added UI state controllers:
  - timeline controller with bounded history,
  - cache controller with snapshot loading/error states.
- Added UI screens:
  - cache inspector,
  - mutation timeline,
  - optimistic updates panel.
- Added root app shell with tabs and actions (refresh cache, clear timeline).
- Added widget test for baseline app rendering.
