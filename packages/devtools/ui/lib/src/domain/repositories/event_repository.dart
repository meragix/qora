import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Domain repository for observing Qora events and dispatching commands.
abstract interface class EventRepository {
  /// Stream of decoded runtime events.
  Stream<QoraEvent> get events;

  /// Dispatches a command to the runtime bridge.
  Future<Map<String, dynamic>> sendCommand(QoraCommand command);

  /// Loads a full payload referenced by [payloadId] and [totalChunks].
  Future<Object?> fetchFullPayload(String payloadId, int totalChunks);
}
