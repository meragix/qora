<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.3.0] - 2026-03-16

### Added

- `QoraInspector.client` — optional `QoraClient` parameter; when provided, the Query Inspector column exposes Refetch, Invalidate, Remove, Mark Stale, and Simulate Error action buttons; omitting it hides the actions section entirely.
- `OverlayTracker.onQueryRemoved()` — implements the new `QoraTracker` hook; removes the key from `_cacheState` and pushes a `removed` event so `QueriesNotifier` evicts the row immediately.
- `OverlayTracker.onQueryMarkedStale()` — implements the new `QoraTracker` hook; pushes a `QueryEvent(type: updated, status: 'stale')` so `QueryRow` shows the orange stale dot without emitting a timeline fetch entry.
- `QueryInspectorNotifier.markStale()` — now calls `client.markStale()` instead of `client.invalidate()`; the action flags the entry stale without triggering an immediate refetch or loading state on active observers.
- `OverlayTracker.needsSerialization` — returns `true`; satisfies the new `QoraTracker` interface getter added in `qora 0.9.0`.
- `OverlayTracker.onQueryFetched` — now accepts `String? dependsOnKey` named parameter (ignored — dependency graph lives in the IDE extension).

### Fixed

- `OverlayTracker.onQueryFetching()` — was a no-op; now emits a transient `QueryEvent(type: updated, status: 'loading')` directly to the stream (not history) so the status dot turns blue immediately when a fetch begins.
- `OverlayTracker.onQueryInvalidated()` — was missing; now pushes a `QueryEvent.invalidated` to both `_queryHistory` and `_queryController` so the dot updates on invalidation.
- `QueriesNotifier` — now removes the entry from `_queries` when it receives a `removed` event; previously removed queries remained in the list indefinitely.
- `QueryInspectorNotifier` — now clears `_selected` and calls `notifyListeners()` when the selected query receives a `removed` event; previously the inspector panel continued to show stale metadata after a remove.
- `QoraPanel` — added an `Overlay` widget ancestor so `TextField` can render focus decorations and selection handles; previously focusing `QuerySearchBar` threw `No Overlay widget found`.
- `import 'package:qora/qora.dart' hide MutationEvent` removed — no longer needed since core type is now `MutationUpdate`.

## [0.2.0] - 2026-03-02

### Added

- **`OverlayTracker.onQueryFetching()`** — no-op override satisfying the new `QoraTracker` interface hook; the overlay tracks fetch completion only.
- **`DataDiffTab` implemented** — replaces the "coming soon" stub; shows BEFORE (mutation variables) and AFTER (result or error) in a two-column dark-themed diff view for the mutation selected in `MutationInspectorNotifier`.

## [0.1.0] - 2026-02-28

### Added

- `OverlayTracker` — implements `QoraTracker`; fans out hook calls to typed streams with 200-event ring buffers.
- `QoraInspector` — public `StatefulWidget` entry point; zero overhead in release builds via `kDebugMode` guard.
- Domain notifiers: `QueriesNotifier`, `MutationsNotifier`, `MutationInspectorNotifier`, `TimelineNotifier`, `CacheNotifier`.
- `MutationDetail` — view-model entity derived from `MutationEvent` for the inspector panel.
- UI shell: `QoraFab`, `FabBadge`, `QoraPanel`, `PanelHeader`, `PanelTabBar`, `ResponsivePanelLayout`.
- Panels: `QueriesPanelView`, `MutationsTabView`, `MutationInspectorColumn`, `TimelineTab`.
- Shared widgets: `StatusBadge`, `ExpandableObject`, `BreadcrumbKey`.
- Stub tabs: `WidgetTreeTab` (coming soon).
- `provider` dependency for `ChangeNotifier`-based state wiring.
- Initial package scaffold.
