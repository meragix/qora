import 'package:qora/qora.dart';
import 'package:qora_devtools_extension/src/lazy/lazy_payload_manager.dart';
import 'package:qora_devtools_extension/src/tracker/qora_client_tracking_gateway.dart';
import 'package:qora_devtools_extension/src/tracker/vm_qora_tracker.dart';
import 'package:qora_devtools_extension/src/vm/extension_handlers.dart';
import 'package:qora_devtools_extension/src/vm/extension_registrar.dart';

/// Zero-config DevTools bridge for [QoraClient].
///
/// [QoraDevtools.setup] condenses the five-step manual wiring into a single
/// call.  Internally it:
///
/// 1. Creates a shared [LazyPayloadManager] for large-payload chunking.
/// 2. Creates a [VmTracker] backed by that manager.
/// 3. Wraps the tracker in a [MultiTracker] when [additionalTrackers] are
///    provided (e.g. an in-app overlay tracker).
/// 4. Installs the tracker on [client] via [QoraClient.setTracker].
/// 5. Registers all `ext.qora.*` VM service extension handlers via
///    [ExtensionRegistrar.registerAll].
///
/// ## Typical usage
///
/// ```dart
/// // main.dart
/// void main() {
///   final client = QoraClient(
///     config: const QoraClientConfig(debugMode: kDebugMode),
///   );
///
///   if (kDebugMode) QoraDevtools.setup(client);
///
///   runApp(MyApp(client: client));
/// }
/// ```
///
/// ## With the in-app overlay
///
/// ```dart
/// final overlay = OverlayTracker();
///
/// if (kDebugMode) {
///   QoraDevtools.setup(client, additionalTrackers: [overlay]);
/// }
///
/// runApp(QoraInspector(tracker: overlay, child: MyApp(client: client)));
/// ```
///
/// ## Release builds
///
/// Guard the call with `kDebugMode` (or `kProfileMode` if profiling is
/// needed).  The `qora_devtools_extension` package is only ever imported in
/// debug/profile entry points, so release bundles stay clean.
abstract final class QoraDevtools {
  /// Wires the DevTools bridge to [client] in a single call.
  ///
  /// [client] — the [QoraClient] to observe. Must have been created with the
  /// default [NoOpTracker] (i.e. without an explicit `tracker:` argument);
  /// passing a client that already has an active tracker is a programming
  /// error and asserts in debug mode.
  ///
  /// [additionalTrackers] — extra [QoraTracker] implementations to activate
  /// alongside [VmTracker].  When non-empty, a [MultiTracker] is created so
  /// every tracker receives the same events.  Typical use: pass an
  /// [OverlayTracker] here to display the in-app DevTools panel while the IDE
  /// extension is also connected.
  ///
  /// [maxBuffer] — ring-buffer size for [VmTracker] (default 500 events).
  /// Tune down on memory-constrained devices.
  static void setup(
    QoraClient client, {
    List<QoraTracker> additionalTrackers = const [],
    int maxBuffer = 500,
  }) {
    final lazy = LazyPayloadManager();
    final vmTracker = VmTracker(lazyPayloadManager: lazy, maxBuffer: maxBuffer);

    final QoraTracker tracker;
    if (additionalTrackers.isEmpty) {
      tracker = vmTracker;
    } else {
      tracker = MultiTracker([vmTracker, ...additionalTrackers]);
    }

    client.setTracker(tracker);

    ExtensionRegistrar(
      handlers: ExtensionHandlers(
        gateway: QoraClientTrackingGateway(client),
        lazyPayloadManager: lazy,
      ),
    ).registerAll();
  }
}
