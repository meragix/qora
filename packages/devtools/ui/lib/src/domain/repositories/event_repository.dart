import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Central domain contract for communicating with the Qora runtime bridge.
///
/// [EventRepository] is the **primary port** of the DevTools UI's domain
/// layer.  Every use-case that reads events or sends commands programs against
/// this interface, not against [VmServiceClient] or any other data-layer
/// class.  This enforces the Dependency Inversion Principle: high-level
/// policy (domain) depends on an abstraction, not on a concrete WebSocket
/// adapter.
///
/// ## Three responsibilities
///
/// | Member               | Direction        | Purpose                               |
/// |----------------------|------------------|---------------------------------------|
/// | [events]             | runtime → UI     | Real-time event push stream           |
/// | [sendCommand]        | UI → runtime     | Trigger actions (refetch, invalidate…)|
/// | [fetchFullPayload]   | UI → runtime     | Reconstruct large chunked payloads    |
///
/// ## Implementations
///
/// - **Production**: [EventRepositoryImpl] — composes [VmServiceClient] and
///   [PayloadRepository].
/// - **Tests**: any class implementing this interface, e.g. a fake that
///   replays a canned list of [QoraEvent]s without a real WebSocket.
///
/// ## Adding a new capability
///
/// 1. Add the method signature here.
/// 2. Implement it in [EventRepositoryImpl] (and update test fakes).
/// 3. Create or extend the appropriate use-case.
///
/// Do **not** add VM-service concerns (isolate ids, WebSocket URIs) to this
/// interface — those belong strictly in the data layer.
abstract interface class EventRepository {
  /// Continuous broadcast stream of [QoraEvent]s decoded from the runtime's
  /// `qora:event` VM extension stream.
  ///
  /// The stream is endless — it emits until the DevTools panel is closed or
  /// [VmServiceClient] disconnects.  Callers must cancel subscriptions in
  /// `dispose` / `onDetach` to avoid memory leaks (see [ObserveEventsUseCase]).
  Stream<QoraEvent> get events;

  /// Dispatches [command] to the connected runtime via
  /// `callServiceExtension` and returns the raw response map.
  ///
  /// The caller interprets the response (e.g. checks `response['ok']`).
  /// Throws if the runtime is disconnected or the extension call fails.
  Future<Map<String, dynamic>> sendCommand(QoraCommand command);

  /// Reconstructs the full JSON value for the payload identified by
  /// [payloadId] by fetching [totalChunks] sequential 80 KB base64 chunks
  /// from [PayloadStore] and JSON-decoding the result.
  ///
  /// Called by [FetchLargePayloadUseCase] when an event carries
  /// `hasLargePayload=true`.  Throws [StateError] if any chunk is empty
  /// (e.g. 30 s TTL expired in [PayloadStore]).
  Future<Object?> fetchFullPayload(String payloadId, int totalChunks);
}
