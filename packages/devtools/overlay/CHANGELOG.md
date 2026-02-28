# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.1.0] - 2026-02-28

### Added

- `OverlayTracker` — implements `QoraTracker`; fans out hook calls to typed streams with 200-event ring buffers
- `QoraInspector` — public `StatefulWidget` entry point; zero overhead in release builds via `kDebugMode` guard
- Domain notifiers: `QueriesNotifier`, `MutationsNotifier`, `MutationInspectorNotifier`, `TimelineNotifier`, `CacheNotifier`
- `MutationDetail` — view-model entity derived from `MutationEvent` for the inspector panel
- UI shell: `QoraFab`, `FabBadge`, `QoraPanel`, `PanelHeader`, `PanelTabBar`, `ResponsivePanelLayout`
- Panels: `QueriesPanelView`, `MutationsTabView`, `MutationInspectorColumn`, `TimelineTab`
- Shared widgets: `StatusBadge`, `ExpandableObject`, `BreadcrumbKey`
- Stub tabs: `WidgetTreeTab`, `DataDiffTab` (coming soon)
- `provider` dependency for `ChangeNotifier`-based state wiring
- Initial package scaffold.
