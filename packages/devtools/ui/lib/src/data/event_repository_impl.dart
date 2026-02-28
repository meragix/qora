import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/data/vm_service_client.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';
import 'package:qora_devtools_ui/src/domain/repositories/payload_repository.dart';

/// Concrete implementation of the domain [EventRepository] interface for the
/// DevTools UI.
///
/// ## Architecture role
///
/// [EventRepositoryImpl] sits at the boundary between the **data layer**
/// (VM service / WebSocket) and the **domain layer** (use-cases, notifiers).
/// It composes two lower-level dependencies:
///
/// - [VmServiceClient] — manages the WebSocket connection, decodes the
///   `qora:event` push stream, and dispatches pull commands.
/// - [PayloadRepository] — reconstructs large payloads from sequential
///   [GetPayloadChunkCommand] calls (see [PayloadRepositoryImpl]).
///
/// By hiding these behind the domain [EventRepository] interface, use-cases
/// remain fully testable with fake implementations.
///
/// ## Responsibilities
///
/// | Method                 | Delegation target                             |
/// |------------------------|-----------------------------------------------|
/// | [events]               | `VmServiceClient.events`                      |
/// | [sendCommand]          | `VmServiceClient.sendCommand`                 |
/// | [fetchFullPayload]     | `PayloadRepository.fetchPayload`              |
///
/// ## Scaling note — lazy payload path
///
/// [fetchFullPayload] is called by [FetchLargePayloadUseCase] when an event
/// carries `hasLargePayload=true`.  It sequentially requests all chunks and
/// deserialises the JSON result.  See [PayloadRepositoryImpl] for the
/// sequential-vs-parallel rationale.
class EventRepositoryImpl implements EventRepository {
  /// Creates a repository composing [vmClient] and [payloadRepository].
  const EventRepositoryImpl({
    required VmServiceClient vmClient,
    required PayloadRepository payloadRepository,
  })  : _vmClient = vmClient,
        _payloadRepository = payloadRepository;

  final VmServiceClient _vmClient;
  final PayloadRepository _payloadRepository;

  /// Continuous broadcast stream of decoded [QoraEvent]s from the runtime.
  ///
  /// Delegated to [VmServiceClient.events].
  @override
  Stream<QoraEvent> get events => _vmClient.events;

  /// Sends [command] to the connected runtime and returns the response map.
  ///
  /// Delegated to [VmServiceClient.sendCommand].
  @override
  Future<Map<String, dynamic>> sendCommand(QoraCommand command) {
    return _vmClient.sendCommand(command);
  }

  /// Reconstructs the full payload identified by [payloadId] by fetching all
  /// [totalChunks] 80 KB base64 chunks from [PayloadRepository] and
  /// JSON-decoding the concatenated bytes.
  ///
  /// Throws [StateError] if any chunk returns an empty `data` field (e.g.
  /// the 30 s TTL expired before all chunks were retrieved).
  @override
  Future<Object?> fetchFullPayload(String payloadId, int totalChunks) {
    return _payloadRepository.fetchPayload(
      payloadId: payloadId,
      totalChunks: totalChunks,
    );
  }
}
