import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/data/vm_service_client.dart';

/// Thin data-layer adapter that surfaces the typed Qora protocol on top of
/// [VmServiceClient].
///
/// This class lives in the **data** layer and acts as a lightweight façade
/// over [VmServiceClient].  It is distinct from the domain-layer
/// `EventRepository` interface (in `domain/repositories/`), which has a richer
/// contract that also covers large-payload retrieval.
///
/// ## Responsibilities
///
/// | Member   | Delegation target                   | Purpose                       |
/// |----------|-------------------------------------|-------------------------------|
/// | [events] | `VmServiceClient.events`            | Decoded `qora:event` stream   |
/// | [send]   | `VmServiceClient.sendCommand`       | Fire-and-forget control calls |
///
/// ## Relationship to [EventRepositoryImpl]
///
/// [EventRepositoryImpl] implements the domain `EventRepository` interface
/// and composes [VmServiceClient] with [PayloadRepository] for large-payload
/// support.  This simpler adapter is used by components that only need event
/// streaming and basic command dispatch (no chunked payload retrieval).
///
/// ## Threading
///
/// All calls are non-blocking and executed on the Flutter UI isolate.
/// [VmServiceClient] ensures the underlying WebSocket is ready before
/// forwarding requests.
class EventRepository {
  /// Creates a data-layer repository backed by [_client].
  const EventRepository(this._client);

  final VmServiceClient _client;

  /// Continuous stream of [QoraEvent]s decoded from the `qora:event` VM
  /// extension stream.
  ///
  /// Backed by [VmServiceClient.events].  Subscribers receive events in
  /// real-time as the runtime pushes them.  The stream is a broadcast stream —
  /// multiple listeners are allowed, but only events emitted *after*
  /// subscription are delivered.
  Stream<QoraEvent> get events => _client.events;

  /// Dispatches [command] to the connected runtime via
  /// `callServiceExtension` and returns the response map.
  ///
  /// Forwards directly to [VmServiceClient.sendCommand].
  Future<Map<String, dynamic>> send(QoraCommand command) {
    return _client.sendCommand(command);
  }
}
