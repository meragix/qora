import 'dart:collection';
import 'dart:convert';

import 'package:qora/qora.dart' show QoraTracker;
import 'package:qora_devtools_extension/src/lazy/lazy_payload_manager.dart';
import 'package:qora_devtools_extension/src/vm/vm_event_pusher.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// `QoraTracker` implementation that publishes runtime events to Flutter DevTools.
///
/// [VmTracker] is the **concrete bridge** between the Qora core and the DevTools
/// UI. It:
/// - receives hooks from `QoraClient` via the `QoraTracker` interface,
/// - converts them to typed [QoraEvent] protocol objects,
/// - optionally stores large payloads as lazy chunks via [LazyPayloadManager],
/// - publishes events to the VM service `"Extension"` stream via [VmEventPusher].
///
/// ## Ring buffer
///
/// Recent events are kept in a bounded [ListQueue] (`maxBuffer`, default 500).
/// When the buffer is full, the oldest event is evicted (FIFO). This guarantees
/// **O(1) memory** regardless of how long the app runs.
///
/// The 500-event default covers roughly:
/// - ~60 s of a high-frequency app (8 events/s),
/// - ~8 min of a typical CRUD app (1 event/s).
///
/// Tune [maxBuffer] down if memory pressure is a concern on low-end devices.
///
/// ## Disposal lifecycle
///
/// Call [dispose] before the owning `QoraClient` is garbage-collected.
/// After disposal, all hook methods are no-ops — no events are emitted and no
/// memory is allocated. This prevents use-after-free bugs when the DevTools
/// tab is closed while the app is still running.
///
/// ## Dependency injection
///
/// [VmTracker] is injected into `QoraClient` only in debug/profile builds:
///
/// ```dart
/// // debug/main.dart
/// final tracker = VmTracker();
/// final client  = QoraClient(tracker: tracker);
///
/// // Release builds use the default NoOpTracker (zero overhead).
/// ```
///
/// ## Thread safety
///
/// Dart isolates are single-threaded. All calls to [VmTracker] are
/// synchronous within the app isolate — no locking is needed.
class VmTracker implements QoraTracker {
  /// Creates a VM tracker.
  ///
  /// [lazyPayloadManager] — shared instance used to store and serve large
  /// payloads. Pass the same instance to [ExtensionHandlers] so that chunks
  /// stored here can be retrieved by the DevTools UI.
  ///
  /// [eventPusher] — injectable for testing; defaults to [VmEventPusher].
  ///
  /// [maxBuffer] — maximum number of events kept in the ring buffer.
  /// Older events are silently discarded when the limit is reached.
  VmTracker({
    LazyPayloadManager? lazyPayloadManager,
    VmEventPusher? eventPusher,
    int maxBuffer = 500,
  })  : _lazy = lazyPayloadManager ?? LazyPayloadManager(),
        _pusher = eventPusher ?? const VmEventPusher(),
        _maxBuffer = maxBuffer;

  final LazyPayloadManager _lazy;
  final VmEventPusher _pusher;
  final int _maxBuffer;

  final ListQueue<QoraEvent> _buffer = ListQueue<QoraEvent>();
  bool _disposed = false;

  /// A read-only copy of the ring buffer contents, oldest to newest.
  ///
  /// Useful for testing and for replay scenarios when a new DevTools tab
  /// connects mid-session. The snapshot is taken at call time — subsequent
  /// emits do not mutate the returned list.
  List<QoraEvent> get recentEvents => List<QoraEvent>.unmodifiable(_buffer);

  void _emit(QoraEvent event) {
    if (_disposed) {
      return;
    }

    if (_buffer.length >= _maxBuffer) {
      _buffer.removeFirst();
    }
    _buffer.addLast(event);
    _pusher.push(event);
  }

  @override
  void onQueryFetched(String key, Object? data, dynamic status) {
    final lazy = _lazy.store(data);
    final summary = _summarizeData(data);

    _emit(
      QueryEvent.fetched(
        key: key,
        data: lazy.hasLargePayload ? null : data,
        status: status,
        hasLargePayload: lazy.hasLargePayload,
        payloadId: lazy.hasLargePayload ? lazy.payloadId : null,
        totalChunks: lazy.hasLargePayload ? lazy.totalChunks : null,
        summary: summary,
      ),
    );
  }

  @override
  void onQueryInvalidated(String key) {
    _emit(QueryEvent.invalidated(key: key));
  }

  @override
  void onMutationStarted(String id, String key, Object? variables) {
    _emit(MutationEvent.started(id: id, key: key, variables: variables));
  }

  @override
  void onMutationSettled(String id, bool success, Object? result) {
    _emit(
      MutationEvent.settled(
        id: id,
        key: '',
        success: success,
        result: result,
      ),
    );
  }

  @override
  void onOptimisticUpdate(String key, Object? optimisticData) {
    _emit(
      GenericQoraEvent(
        eventId: QoraEvent.generateId(),
        kind: 'optimistic.applied',
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        payload: <String, Object?>{
          'queryKey': key,
          'data': optimisticData,
        },
      ),
    );
  }

  @override
  void onCacheCleared() {
    _emit(
      GenericQoraEvent(
        eventId: QoraEvent.generateId(),
        kind: 'cache.cleared',
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _buffer.clear();
    _lazy.clear();
  }

  Map<String, Object?> _summarizeData(Object? data) {
    int? approximateBytes;
    try {
      approximateBytes = utf8.encode(jsonEncode(data)).length;
    } catch (_) {
      approximateBytes = null;
    }

    final itemCount = switch (data) {
      List<Object?> value => value.length,
      Map<Object?, Object?> value => value.length,
      _ => null,
    };

    return <String, Object?>{
      if (approximateBytes != null) 'approxBytes': approximateBytes,
      if (itemCount != null) 'itemCount': itemCount,
    };
  }
}
