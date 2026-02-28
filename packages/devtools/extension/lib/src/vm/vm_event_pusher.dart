import 'dart:developer' as developer;

import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Thin abstraction over `developer.postEvent` that keeps [VmTracker] testable.
///
/// Wrapping `developer.postEvent` in its own class lets tests inject a fake
/// implementation without patching `dart:developer`:
///
/// ```dart
/// class CapturingPusher implements VmEventPusher {
///   final pushed = <QoraEvent>[];
///   @override
///   void push(QoraEvent event) => pushed.add(event);
/// }
///
/// final tracker = VmTracker(eventPusher: CapturingPusher());
/// tracker.onQueryFetched('todos', data, 'success');
/// expect(capturingPusher.pushed, hasLength(1));
/// ```
///
/// In production, the default [VmEventPusher] calls `developer.postEvent`,
/// which is a **no-op in release mode** (stripped at compile time).
class VmEventPusher {
  /// Creates a VM event pusher.
  const VmEventPusher();

  /// Serialises [event] and posts it to the Dart VM extension stream.
  ///
  /// The event kind is always [QoraExtensionEvents.qoraEvent] (`'qora:event'`).
  /// The DevTools UI subscribes to this stream name and filters by that kind.
  ///
  /// This call is **synchronous and non-blocking** — `developer.postEvent`
  /// enqueues the payload without waiting for the DevTools UI to consume it.
  void push(QoraEvent event) {
    developer.postEvent(QoraExtensionEvents.qoraEvent, event.toJson());
  }
}
