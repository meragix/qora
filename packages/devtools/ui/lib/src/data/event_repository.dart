import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/data/vm_service_client.dart';

/// Data-layer adapter that exposes typed protocol events from VM service.
class EventRepository {
  /// Creates repository from [VmServiceClient].
  const EventRepository(this._client);

  final VmServiceClient _client;

  /// Stream of decoded Qora events.
  Stream<QoraEvent> get events => _client.events;

  /// Sends command to the connected runtime.
  Future<Map<String, dynamic>> send(QoraCommand command) {
    return _client.sendCommand(command);
  }
}
