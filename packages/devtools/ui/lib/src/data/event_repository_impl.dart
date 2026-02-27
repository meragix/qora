import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/data/vm_service_client.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';
import 'package:qora_devtools_ui/src/domain/repositories/payload_repository.dart';

/// Event repository implementation for the DevTools UI.
class EventRepositoryImpl implements EventRepository {
  /// Creates a repository from lower-level dependencies.
  const EventRepositoryImpl({
    required VmServiceClient vmClient,
    required PayloadRepository payloadRepository,
  })  : _vmClient = vmClient,
        _payloadRepository = payloadRepository;

  final VmServiceClient _vmClient;
  final PayloadRepository _payloadRepository;

  @override
  Stream<QoraEvent> get events => _vmClient.events;

  @override
  Future<Map<String, dynamic>> sendCommand(QoraCommand command) {
    return _vmClient.sendCommand(command);
  }

  @override
  Future<Object?> fetchFullPayload(String payloadId, int totalChunks) {
    return _payloadRepository.fetchPayload(
      payloadId: payloadId,
      totalChunks: totalChunks,
    );
  }
}
