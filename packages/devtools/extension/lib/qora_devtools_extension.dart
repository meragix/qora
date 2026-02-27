/// Runtime bridge for exposing Qora internals to Flutter DevTools.
///
/// `qora_devtools_extension` runs inside the application isolate and provides:
/// - a [VmTracker] implementation of `QoraTracker`,
/// - VM service extension registration (`ext.qora.*`),
/// - lazy payload chunking/storage for large JSON objects.
library;

export 'src/lazy/lazy_payload_manager.dart';
export 'src/lazy/payload_chunker.dart';
export 'src/lazy/payload_store.dart';
export 'src/tracker/tracking_gateway.dart';
export 'src/tracker/vm_qora_tracker.dart';
export 'src/vm/extension_handlers.dart';
export 'src/vm/extension_registrar.dart';
export 'src/vm/vm_event_pusher.dart';
