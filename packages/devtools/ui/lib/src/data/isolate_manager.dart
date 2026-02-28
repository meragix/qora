import 'package:vm_service/vm_service.dart';

/// Selects the correct app isolate from the Dart VM for DevTools extension
/// calls.
///
/// ## Why isolate selection matters
///
/// A Dart VM can host **multiple isolates** simultaneously:
/// - The main app isolate (where Qora extensions are registered)
/// - Web-worker-style background isolates
/// - The VM's own system / service isolates
///
/// Qora's VM extensions (`ext.qora.*`) are registered on the **main app
/// isolate** only.  Sending a `callServiceExtension` to the wrong isolate
/// returns a `methodNotFound` error.  [QoraIsolateManager] ensures that
/// [VmServiceClient] always targets the correct isolate.
///
/// ## Selection strategy
///
/// [selectMainIsolateId] iterates the VM's isolate list and returns the
/// **first runnable** isolate.  For a typical Flutter or Dart application:
///
/// ```
/// vm.isolates ──▶ [mainIsolate (runnable), backgroundIsolate, systemIsolate]
///                          ↑
///                   returned id
/// ```
///
/// A `runnable` flag means the isolate has completed startup and is executing
/// Dart code — i.e. it can handle extension calls.
///
/// ## Limitations
///
/// - **Multi-isolate apps**: apps that spin up multiple user isolates may
///   register Qora extensions on a non-first isolate.  In that case a more
///   targeted heuristic (e.g. matching the isolate name) may be needed.
/// - **Hot-restart**: after hot-restart a new isolate replaces the old one.
///   [VmServiceClient] re-selects the isolate via [selectMainIsolateId]
///   on each reconnect.
class QoraIsolateManager {
  /// Creates an isolate manager (stateless, safe to share).
  const QoraIsolateManager();

  /// Returns the id of the first runnable non-system isolate in [vm], or
  /// `null` if no suitable isolate is found.
  ///
  /// Iterates [VM.isolates] in order, fetches each [Isolate], and returns
  /// the id of the first one whose `runnable` flag is `true`.
  ///
  /// Returns `null` if:
  /// - [vm] has no isolates (`vm.isolates` is null or empty).
  /// - All isolates are still starting up (`runnable == false`).
  ///
  /// [VmServiceClient.connect] awaits this call and caches the result for
  /// the lifetime of the connection.
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
