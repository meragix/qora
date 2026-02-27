import 'package:vm_service/vm_service.dart';

/// Utility for selecting the most relevant isolate for DevTools calls.
class QoraIsolateManager {
  /// Creates isolate manager.
  const QoraIsolateManager();

  /// Returns the first non-system isolate id, or `null` if none.
  Future<String?> selectMainIsolateId(VmService service, VM vm) async {
    for (final ref in vm.isolates ?? const <IsolateRef>[]) {
      final id = ref.id;
      if (id == null) continue;
      final isolate = await service.getIsolate(id);
      if (isolate.runnable ?? false) {
        return id;
      }
    }
    return null;
  }
}
