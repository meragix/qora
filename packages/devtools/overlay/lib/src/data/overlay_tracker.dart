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

  // Start timestamps (ms since epoch) for in-flight fetches and mutations.
  final _fetchStartMs = <String, int>{};
  final _mutationStartMs = <String, int>{};

  // Keys that received an onOptimisticUpdate before a mutation started.
  // Consumed (removed) in onMutationStarted to infer isOptimistic.
  final _pendingOptimisticKeys = <String>{};

  // Mutation IDs confirmed as optimistic, kept until settled.
  final _optimisticMutationIds = <String>{};

  // First-seen timestamp per query key (ms since epoch).
  final _queryCreatedAt = <String, int>{};

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
  void onQueryFetching(String key) {
    if (_disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isNew = !_queryCreatedAt.containsKey(key);
    _fetchStartMs[key] = now;
    // Emit a transient loading event so the status dot turns blue immediately.
    // Not recorded in history — the subsequent onQueryFetched event will be.
    _queryController.add(QueryEvent(
      eventId: QoraEvent.generateId(),
      timestampMs: now,
      type: QueryEventType.updated,
      key: key,
      status: 'loading',
      createdAtMs: _createdAt(key, now),
    ));
    _emitTimeline(
      isNew ? TimelineEventType.queryCreated : TimelineEventType.fetchStarted,
      key,
    );
  }

  @override
  void onQueryFetched(
    String key,
    Object? data,
    dynamic status, {
    int? staleTimeMs,
    int? gcTimeMs,
    int observerCount = 0,
    int? retryCount,
  }) {
    if (_disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final event = QueryEvent.fetched(
      key: key,
      status: status,
      data: data,
      staleTimeMs: staleTimeMs,
      gcTimeMs: gcTimeMs,
      observerCount: observerCount,
      createdAtMs: _createdAt(key, now),
      retryCount: retryCount,
    );
    _push(_queryHistory, _queryController, event);
    _cacheState[key] = QuerySnapshot(
      key: key,
      status: status?.toString() ?? 'success',
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final isError = status?.toString() == 'error';
    final startMs = _fetchStartMs.remove(key);
    final duration = startMs != null ? now - startMs : null;
    _emitTimeline(
      isError ? TimelineEventType.fetchError : TimelineEventType.fetchSuccess,
      key,
      duration: duration,
    );
  }

  @override
  void onQueryCancelled(String key) {
    if (_disposed) return;
    _cacheState.remove(key);
    _emitTimeline(TimelineEventType.queryCancelled, key);
  }

  @override
  void onQueryRemoved(String key) {
    if (_disposed) return;
    _cacheState.remove(key);
    _queryCreatedAt.remove(key);
    _push(
      _queryHistory,
      _queryController,
      QueryEvent(
        eventId: QoraEvent.generateId(),
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        type: QueryEventType.removed,
        key: key,
      ),
    );
    _emitTimeline(TimelineEventType.queryRemoved, key);
  }

  @override
  void onQueryInvalidated(String key) {
    if (_disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _push(
      _queryHistory,
      _queryController,
      QueryEvent(
        eventId: QoraEvent.generateId(),
        timestampMs: now,
        type: QueryEventType.invalidated,
        key: key,
        createdAtMs: _queryCreatedAt[key],
      ),
    );
    _emitTimeline(TimelineEventType.queryInvalidated, key);
  }

  @override
  void onQueryMarkedStale(String key) {
    if (_disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Emit an updated event with status 'stale' so QueryRow shows the stale
    // dot without emitting a timeline fetch entry.
    _push(
      _queryHistory,
      _queryController,
      QueryEvent(
        eventId: QoraEvent.generateId(),
        timestampMs: now,
        type: QueryEventType.updated,
        key: key,
        status: 'stale',
        createdAtMs: _queryCreatedAt[key],
      ),
    );
    _emitTimeline(TimelineEventType.queryMarkedStale, key);
  }

  @override
  void onMutationStarted(String id, String key, Object? variables) {
    if (_disposed) return;
    _mutationKeys[id] = key;
    _mutationStartMs[id] = DateTime.now().millisecondsSinceEpoch;
    final isOptimistic = _pendingOptimisticKeys.remove(key);
    if (isOptimistic) _optimisticMutationIds.add(id);
    final event = MutationEvent.started(
      id: id,
      key: key,
      variables: variables,
      isOptimistic: isOptimistic,
    );
    _push(_mutationHistory, _mutationController, event);
    _emitTimeline(TimelineEventType.mutationStarted, key, id: id);
  }

  @override
  void onMutationSettled(String id, bool success, Object? result) {
    if (_disposed) return;
    final key = _mutationKeys[id] ?? '';
    final startMs = _mutationStartMs.remove(id);
    final duration = startMs != null
        ? DateTime.now().millisecondsSinceEpoch - startMs
        : null;
    final isOptimistic = _optimisticMutationIds.remove(id);
    final event = MutationEvent.settled(
      id: id,
      key: key,
      success: success,
      result: result,
      isOptimistic: isOptimistic,
    );
    _push(_mutationHistory, _mutationController, event);
    _emitTimeline(
      success
          ? TimelineEventType.mutationSuccess
          : TimelineEventType.mutationError,
      key.isEmpty ? null : key,
      id: id,
      duration: duration,
    );
  }

  @override
  void onOptimisticUpdate(String key, Object? optimisticData) {
    if (_disposed) return;
    // Mark this key so the next onMutationStarted for the same key is flagged
    // as optimistic. The entry is consumed (removed) in onMutationStarted.
    _pendingOptimisticKeys.add(key);
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
    _pendingOptimisticKeys.clear();
    _optimisticMutationIds.clear();
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
    _queryCreatedAt.clear();
    _fetchStartMs.clear();
    _mutationStartMs.clear();
    _pendingOptimisticKeys.clear();
    _optimisticMutationIds.clear();
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  /// Returns the first-seen timestamp for [key], recording [now] if this is
  /// the first time the key is observed.
  int _createdAt(String key, int now) =>
      _queryCreatedAt.putIfAbsent(key, () => now);

  void _emitTimeline(TimelineEventType type, String? key,
      {String? id, int? duration}) {
    final event = TimelineEvent(
      type: type,
      key: key,
      mutationId: id,
      timestamp: DateTime.now(),
      duration: duration,
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
