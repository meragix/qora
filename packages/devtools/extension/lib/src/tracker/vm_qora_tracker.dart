import 'dart:collection';
import 'dart:convert';

import 'package:qora/qora.dart' show QoraTracker;
import 'package:qora_devtools_extension/src/lazy/lazy_payload_manager.dart';
import 'package:qora_devtools_extension/src/vm/vm_event_pusher.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// `QoraTracker` implementation that publishes runtime events to DevTools.
///
/// Key properties:
/// - bounded in-memory ring buffer,
/// - optional lazy payload metadata for large JSON values,
/// - graceful no-op after disposal.
class VmTracker implements QoraTracker {
  /// Creates a VM tracker.
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

  /// Returns a copy of recently emitted events (oldest to newest).
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
