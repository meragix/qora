/// Qora DevTools Overlay — in-app debug panel.
///
/// A debug-only overlay that injects a floating action button and a 3-column
/// panel (Queries / Mutations / Timeline) directly into the running Flutter app.
/// Zero overhead in release builds — the entire widget tree is guarded by
/// [kDebugMode] and tree-shaken by the Dart compiler.
///
/// ## Quick start
///
/// ```dart
/// // 1. Create a tracker and connect it to QoraClient:
/// final tracker = OverlayTracker();
/// final client  = QoraClient(tracker: tracker);
///
/// // 2. Wrap your app:
/// runApp(
///   QoraInspector(
///     tracker: tracker,
///     child: MyApp(),
///   ),
/// );
/// ```
library qora_devtools_overlay;

// Public API — the two types users need to wire the overlay.
export 'src/data/overlay_tracker.dart' show OverlayTracker;
export 'src/ui/qora_inspector.dart' show QoraInspector;
