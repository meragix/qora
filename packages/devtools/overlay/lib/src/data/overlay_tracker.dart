import 'dart:async';
import 'dart:collection';

// Hide core MutationEvent — the overlay uses the shared protocol MutationEvent.
import 'package:qora/qora.dart' hide MutationEvent;
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Lightweight value object for an optimistic cache write recorded by the overlay.
///
/// Created in [OverlayTracker.onOptimisticUpdate] and pushed to [OverlayTracker.onOptimistic].
/// [preview] is a truncated string representation of the written data (max 200 chars).
class OptimisticEvent {
  final String key;
  final String? preview;
  final DateTime timestamp;

  const OptimisticEvent({
    required this.key,
    this.preview,
    required this.timestamp,
  });
}

/// In-process [QoraTracker] implementation for the overlay DevTools panel.
///
/// Converts [QoraTracker] hook calls into typed events and fans them out to
/// broadcast [Stream]s and bounded ring-buffers. The domain notifiers listen
/// to these streams and expose filtered/paused views to the UI.
///
/// ## Memory safety
///
/// All ring-buffers are capped at [_kMaxEvents] (200) via FIFO eviction.
/// [dispose] closes all streams and clears all buffers, preventing leaks when
/// the [QoraInspector] widget is removed from the tree.
///
/// ## Usage
///
/// ```dart
/// final tracker = OverlayTracker();
/// final client  = QoraClient(tracker: tracker);
/// runApp(QoraInspector(tracker: tracker, child: MyApp()));
/// ```
class OverlayTracker implements QoraTracker {
  static const int _kMaxEvents = 200;

  final _queryController = StreamController<QueryEvent>.broadcast();
  final _mutationController = StreamController<MutationEvent>.broadcast();
  final _optimisticController = StreamController<OptimisticEvent>.broadcast();
  final _timelineController = StreamController<TimelineEvent>.broadcast();

  // Ring-buffers — bounded memory, O(1) eviction
  final _queryHistory = ListQueue<QueryEvent>(_kMaxEvents);
  final _mutationHistory = ListQueue<MutationEvent>(_kMaxEvents);
  final _timelineHistory = ListQueue<TimelineEvent>(_kMaxEvents);

  // Current cache state (key → latest snapshot)
  final _cacheState = <String, QuerySnapshot>{};

  // Tracks mutation id → query key for settled events (key not provided by interface)
  final _mutationKeys = <String, String>{};

  bool _disposed = false;

  // ── Public streams ──────────────────────────────────────────────────────────

  Stream<QueryEvent> get onQuery => _queryController.stream;
  Stream<MutationEvent> get onMutation => _mutationController.stream;
  Stream<OptimisticEvent> get onOptimistic => _optimisticController.stream;
  Stream<TimelineEvent> get onTimeline => _timelineController.stream;

  // ── Synchronous snapshots (for panel initialisation) ────────────────────────

  List<QueryEvent> get queryHistory => List.unmodifiable(_queryHistory);
  List<MutationEvent> get mutationHistory =>
      List.unmodifiable(_mutationHistory);
  List<TimelineEvent> get timelineHistory =>
      List.unmodifiable(_timelineHistory);
  Map<String, QuerySnapshot> get cacheSnapshot => Map.unmodifiable(_cacheState);

  // ── QoraTracker ─────────────────────────────────────────────────────────────

  @override
  void onQueryFetched(String key, Object? data, dynamic status) {
    if (_disposed) return;
    final event = QueryEvent.fetched(key: key, status: status, data: null);
    _push(_queryHistory, _queryController, event);
    _cacheState[key] = QuerySnapshot(
      key: key,
      status: status?.toString() ?? 'success',
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _emitTimeline(TimelineEventType.fetchStarted, key);
  }

  @override
  void onQueryInvalidated(String key) {
    if (_disposed) return;
    _emitTimeline(TimelineEventType.fetchStarted, key);
  }

  @override
  void onMutationStarted(String id, String key, Object? variables) {
    if (_disposed) return;
    _mutationKeys[id] = key;
    final event = MutationEvent.started(id: id, key: key, variables: variables);
    _push(_mutationHistory, _mutationController, event);
    _emitTimeline(TimelineEventType.mutationStarted, key, id: id);
  }

  @override
  void onMutationSettled(String id, bool success, Object? result) {
    if (_disposed) return;
    final key = _mutationKeys[id] ?? '';
    final event = MutationEvent.settled(
      id: id,
      key: key,
      success: success,
      result: result,
    );
    _push(_mutationHistory, _mutationController, event);
    _emitTimeline(
      success
          ? TimelineEventType.mutationSuccess
          : TimelineEventType.mutationError,
      null,
      id: id,
    );
  }

  @override
  void onOptimisticUpdate(String key, Object? optimisticData) {
    if (_disposed) return;
    _optimisticController.add(OptimisticEvent(
      key: key,
      preview: _truncate(optimisticData),
      timestamp: DateTime.now(),
    ));
    _emitTimeline(TimelineEventType.optimisticUpdate, key);
  }

  @override
  void onCacheCleared() {
    if (_disposed) return;
    _cacheState.clear();
    _mutationKeys.clear();
    _emitTimeline(TimelineEventType.cacheCleared, null);
  }

  @override
  void dispose() {
    _disposed = true;
    _queryController.close();
    _mutationController.close();
    _optimisticController.close();
    _timelineController.close();
    _queryHistory.clear();
    _mutationHistory.clear();
    _timelineHistory.clear();
    _cacheState.clear();
    _mutationKeys.clear();
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  void _emitTimeline(TimelineEventType type, String? key, {String? id}) {
    final event = TimelineEvent(
      type: type,
      key: key,
      mutationId: id,
      timestamp: DateTime.now(),
    );
    if (_timelineHistory.length >= _kMaxEvents) _timelineHistory.removeFirst();
    _timelineHistory.addLast(event);
    _timelineController.add(event);
  }

  void _push<T>(ListQueue<T> buf, StreamController<T> ctrl, T event) {
    if (buf.length >= _kMaxEvents) buf.removeFirst();
    buf.addLast(event);
    ctrl.add(event);
  }

  String? _truncate(Object? data, {int max = 200}) {
    if (data == null) return null;
    final s = data.toString();
    return s.length > max ? '${s.substring(0, max)}…' : s;
  }
}
