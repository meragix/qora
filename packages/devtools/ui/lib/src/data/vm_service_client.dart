import 'dart:async';

import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:vm_service/vm_service.dart';

/// Thin client over `vm_service` dedicated to Qora DevTools communication.
///
/// This client owns:
/// - extension event subscription (`qora:event`),
/// - command dispatch to `ext.qora.*` methods,
/// - stream exposure for decoded [QoraEvent] instances.
class VmServiceClient {
  final StreamController<QoraEvent> _eventController = StreamController<QoraEvent>.broadcast();

  VmService? _service;
  String? _isolateId;
  StreamSubscription<Event>? _extensionEventsSub;

  VmServiceClient();

  /// Decoded stream of Qora protocol events.
  Stream<QoraEvent> get events => _eventController.stream;

  /// `true` when both service and isolate id are configured.
  bool get isConnected => _service != null && _isolateId != null;

  /// Connects this client to a running VM service and target isolate.
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

  /// Ingests one raw extension [event] and publishes decoded protocol events.
  ///
  /// Public for testability and optional manual wiring.
  void ingestExtensionEvent(Event event) {
    _onExtensionEvent(event);
  }

  /// Sends a protocol [command] to the target isolate.
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

    return Map<String, dynamic>.from(response.json ?? const <String, dynamic>{});
  }

  /// Disconnects from VM service and clears event subscriptions.
  Future<void> disconnect() async {
    await _extensionEventsSub?.cancel();
    _extensionEventsSub = null;
    _service = null;
    _isolateId = null;
  }

  /// Releases resources held by this client.
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
