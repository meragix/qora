// ignore_for_file: unused_element
// ---------------------------------------------------------------------------
// PLANNED FEATURE — QoraDevtoolsBinding auto-registration
// ---------------------------------------------------------------------------
//
// ## Status
//
// This file is a **design sketch** for a future zero-config DevTools
// integration.  No production code is active yet; the function body is empty
// and the file is intentionally not exported from the package barrel.
//
// ## Motivation
//
// The current setup requires the host app to manually inject [VmTracker] into
// every `QoraClient` constructor:
//
// ```dart
// // Current (manual wiring):
// final client = QoraClient(tracker: VmTracker());
// ```
//
// This is intentional and explicit, but it can be error-prone in large apps
// with many `QoraClient` instances.  The planned `QoraDevtoolsBinding`
// provides an **opt-in auto-registration path** so the tracker is attached
// automatically in debug/profile builds without touching application code.
//
// ## Planned design — QoraDevtoolsBinding
//
// ```
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  packages/devtools/extension/lib/src/binding.dart  (to be created)      │
// │                                                                          │
// │  class QoraDevtoolsBinding {                                             │
// │    /// Returns [VmTracker] in debug/profile, null in release.            │
// │    static QoraTracker? trackerIfAvailable() {                            │
// │      if (kDebugMode || kProfileMode) return VmTracker();                 │
// │      return null; // → QoraClient falls back to NoOpTracker             │
// │    }                                                                     │
// │                                                                          │
// │    static void ensureInitialized() {                                     │
// │      // Registers VM extensions, wires tracker to all active clients     │
// │    }                                                                     │
// │  }                                                                       │
// └─────────────────────────────────────────────────────────────────────────┘
// ```
//
// ### QoraClient integration (packages/qora)
//
// ```dart
// // Future opt-in auto-detect:
// QoraClient({QoraTracker? tracker})
//   : _tracker = tracker
//       ?? QoraDevtoolsBinding.trackerIfAvailable()  // auto-detect
//       ?? const NoOpTracker();
// ```
//
// ## @pragma('vm:entry-point') mechanism
//
// The `@pragma('vm:entry-point')` annotation prevents the Dart tree-shaker
// from removing a symbol even when it has no visible callers.  For the
// planned implementation, `_qoraDevtoolsInit` would be invoked *before*
// `main()` via the `--observe` / DevTools launch hook, initialising the
// binding without any app-side code change.
//
// This pattern is used by Flutter's own DevTools binding
// (`WidgetsBinding.ensureInitialized`) and is safe in debug/profile builds
// only (the annotation is a no-op in release due to `kDebugMode` guard).
//
// ## Implementation checklist (when ready)
//
// 1. Create `lib/src/binding.dart` with `QoraDevtoolsBinding`.
// 2. Add `trackerIfAvailable()` to the core `qora` package
//    (guarded by `kDebugMode || kProfileMode`).
// 3. Export `QoraDevtoolsBinding` from the package barrel.
// 4. Activate the body of `_qoraDevtoolsInit` below.
// 5. Add integration tests verifying zero-config DevTools attachment.
// ---------------------------------------------------------------------------

/// Auto-registration entry point for the planned [QoraDevtoolsBinding].
///
/// **Not yet active** — the body is empty until [QoraDevtoolsBinding] is
/// implemented (see file-level roadmap comment above).
///
/// When activated, this function will run before `main()` in debug/profile
/// builds and register [VmTracker] with all active `QoraClient` instances
/// automatically, eliminating the need for manual tracker injection.
@pragma('vm:entry-point')
void _qoraDevtoolsInit() {
  // TODO(devtools): Activate once QoraDevtoolsBinding is implemented.
  // if (!kDebugMode && !kProfileMode) return;
  // QoraDevtoolsBinding.ensureInitialized();
}