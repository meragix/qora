import 'dart:developer' as developer;

import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Thin abstraction over `developer.postEvent` to keep tracker logic testable.
class VmEventPusher {
  /// Creates a VM event pusher.
  const VmEventPusher();

  /// Pushes [event] to the VM extension stream consumed by DevTools.
  void push(QoraEvent event) {
    developer.postEvent(QoraExtensionEvents.qoraEvent, event.toJson());
  }
}
