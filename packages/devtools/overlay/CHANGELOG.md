<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
