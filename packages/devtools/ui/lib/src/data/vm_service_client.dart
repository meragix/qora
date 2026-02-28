import 'dart:async';

import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:vm_service/vm_service.dart';

/// Thin client over `vm_service` dedicated to Qora DevTools communication.
///
/// [VmServiceClient] is the **sole point of contact** between the DevTools UI
/// and the Dart VM service. It owns:
/// - extension event subscription (filters `qora:event` from the `Extension`
///   stream),
/// - command dispatch to `ext.qora.*` methods via `callServiceExtension`,
/// - decoded [QoraEvent] broadcast stream exposed to the domain layer.
///
/// ## Connection lifecycle
///
/// ```
/// connect(service, isolateId)     ← DevTools panel activated
///   ↓  streamListen + subscribe
/// events.listen(...)              ← domain layer starts consuming
///   ↓
/// disconnect()                    ← isolate stopped / tab closed
///   ↓
/// dispose()                       ← client object discarded
/// ```
///
/// [connect] is idempotent-safe: it calls [disconnect] before re-subscribing,
/// so it can be called again on hot restart or isolate change.
///
/// ## Testability
///
/// [ingestExtensionEvent] allows test suites to inject synthetic VM service
/// events without a live VM connection, enabling pure-unit test coverage of
/// the event decoding pipeline.
///
/// ## Scaling note
///
/// The [events] stream is a broadcast stream — multiple listeners can
/// subscribe independently without buffering. If a listener is slow (e.g.
/// a heavy UI rebuild), events are not buffered: consider debouncing or
/// batching upstream if event frequency exceeds ~100/s.
class VmServiceClient {
  final StreamController<QoraEvent> _eventController =
      StreamController<QoraEvent>.broadcast();

  VmService? _service;
  String? _isolateId;
  StreamSubscription<Event>? _extensionEventsSub;

  VmServiceClient();

  /// Broadcast stream of decoded [QoraEvent] instances.
  ///
  /// Events are emitted whenever the app side publishes a `qora:event` to
  /// the Dart VM `Extension` stream. Unknown event kinds are decoded as
  /// [GenericQoraEvent] for forward compatibility.
  Stream<QoraEvent> get events => _eventController.stream;

  /// `true` when both [VmService] and an isolate ID are configured.
  bool get isConnected => _service != null && _isolateId != null;

  /// Connects to a running VM service instance and subscribes to events.
  ///
  /// Cancels any previous subscription before establishing the new one.
  /// Subscribes to `EventStreams.kExtension` and filters for `qora:event`.
  ///
  /// Throws only if [VmService.streamListen] fails (e.g. invalid isolate).
  Future<void> connect({
    required VmService service,
    required String isolateId,
  }) async {
    await disconnect();
    _service = service;
    _isolateId = isolateId;

    await service.streamListen(EventStreams.kExtension);
    _extensionEventsSub = service.onExtensionEvent.listen(_onExtensionEvent);
  }

  /// Ingests a raw VM service [event] and publishes it to [events] if it is a
  /// valid Qora protocol event.
  ///
  /// This method is public for **testability**: inject synthetic events in unit
  /// tests without a live VM connection. In production it is driven internally
  /// by the `onExtensionEvent` subscription.
  void ingestExtensionEvent(Event event) {
    _onExtensionEvent(event);
  }

  /// Sends a [QoraCommand] to the target isolate via `callServiceExtension`.
  ///
  /// Returns the decoded JSON response body as a `Map<String, dynamic>`.
  /// Returns an empty map when the response carries no `json` payload.
  ///
  /// Throws [StateError] if called before [connect].
  /// Propagates any `RPCError` from the VM service on handler failures.
  Future<Map<String, dynamic>> sendCommand(QoraCommand command) async {
    final service = _service;
    final isolateId = _isolateId;

    if (service == null || isolateId == null) {
      throw StateError('VmServiceClient is not connected');
    }

    final response = await service.callServiceExtension(
      '${QoraExtensionMethods.prefix}.${command.method}',
      isolateId: isolateId,
      args: command.params,
    );

    return Map<String, dynamic>.from(
        response.json ?? const <String, dynamic>{});
  }

  /// Cancels the event subscription and resets the service/isolate references.
  ///
  /// Safe to call multiple times (idempotent). Does **not** close [events].
  Future<void> disconnect() async {
    await _extensionEventsSub?.cancel();
    _extensionEventsSub = null;
    _service = null;
    _isolateId = null;
  }

  /// Disconnects and closes the [events] stream controller.
  ///
  /// After [dispose], [events] will emit a done notification and no further
  /// events can be published. This client must not be used after disposal.
  Future<void> dispose() async {
    await disconnect();
    await _eventController.close();
  }

  void _onExtensionEvent(Event event) {
    if (event.extensionKind != QoraExtensionEvents.qoraEvent) {
      return;
    }

    final raw = event.extensionData?.data;
    if (raw is! Map) {
      return;
    }

    final decoded = EventCodec.decode(Map<String, Object?>.from(raw as Map));
    _eventController.add(decoded);
  }
}
