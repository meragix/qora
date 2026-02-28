/// Runtime bridge for exposing Qora internals to Flutter DevTools.
///
/// `qora_devtools_extension` runs entirely inside the **application isolate**
/// and has zero runtime cost in release builds — it is only activated when a
/// concrete [VmTracker] is injected into `QoraClient`.
///
/// ## Package layout
///
/// ```
/// qora_devtools_extension/
/// ├── src/
/// │   ├── tracker/
/// │   │   ├── vm_qora_tracker.dart    ← QoraTracker impl (push events)
/// │   │   └── tracking_gateway.dart   ← abstract gateway for commands
/// │   ├── vm/
/// │   │   ├── extension_registrar.dart  ← registers ext.qora.* handlers
/// │   │   ├── extension_handlers.dart   ← per-command handler logic
/// │   │   └── vm_event_pusher.dart      ← thin wrapper over postEvent
/// │   └── lazy/
/// │       ├── lazy_payload_manager.dart  ← orchestrates push/pull strategy
/// │       ├── payload_store.dart          ← LRU+TTL in-memory chunk store
/// │       └── payload_chunker.dart        ← byte-level split/join utility
/// ```
///
/// ## Setup (debug entry point)
///
/// ```dart
/// // main_debug.dart — injected only in debug / profile builds
/// import 'package:qora/qora.dart';
/// import 'package:qora_devtools_extension/qora_devtools_extension.dart';
///
/// void main() {
///   final lazy   = LazyPayloadManager();
///   final tracker = VmTracker(lazyPayloadManager: lazy);
///   final handlers = ExtensionHandlers(
///     gateway: MyTrackingGateway(), // implements TrackingGateway
///     lazyPayloadManager: lazy,
///   );
///   ExtensionRegistrar(handlers: handlers).registerAll();
///
///   runApp(MyApp(client: QoraClient(tracker: tracker)));
/// }
/// ```
///
/// ## Dependency inversion (DIP)
///
/// The core `qora` package only knows about the abstract `QoraTracker`
/// interface. This package provides the concrete [VmTracker] — the core
/// never imports anything from here, keeping production bundles clean.
///
/// ## Memory safety guarantees
///
/// | Mechanism | Component |
/// |-----------|-----------|
/// | Ring buffer capped at N events (default 500) | [VmTracker] |
/// | All emits guarded after `dispose()` | [VmTracker] |
/// | Payload chunks bounded to 20 MB total | [PayloadStore] |
/// | TTL of 30 s per payload entry | [PayloadStore] |
/// | LRU eviction when budget is exceeded | [PayloadStore] |
library;

export 'src/lazy/lazy_payload_manager.dart';
export 'src/lazy/payload_chunker.dart';
export 'src/lazy/payload_store.dart';
export 'src/tracker/tracking_gateway.dart';
export 'src/tracker/vm_qora_tracker.dart';
export 'src/vm/extension_handlers.dart';
export 'src/vm/extension_registrar.dart';
export 'src/vm/vm_event_pusher.dart';
