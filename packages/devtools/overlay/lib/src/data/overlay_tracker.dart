import 'dart:async';
import 'dart:collection';

import 'package:qora/qora.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

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
  final _timelineController = StreamController<TimelineEvent>.broadcast();

  // Ring-buffers: bounded memory, O(1) eviction
  final _queryHistory = ListQueue<QueryEvent>(_kMaxEvents);
  final _mutationHistory = ListQueue<MutationEvent>(_kMaxEvents);
  final _timelineHistory = ListQueue<TimelineEvent>(_kMaxEvents);

  // Last recorded event per key: what a cancelled fetch goes back to, and
  // where a setQueryData row takes the options it cannot know.
  final _lastQueryEvent = <String, QueryEvent>{};

  // Last data written per key, by a successful fetch or setQueryData. Kept
  // apart from _lastQueryEvent, whose invalidate and stale events carry no
  // data: a failure keeps showing this, as the query does.
  final _lastData = <String, Object?>{};

  // Tracks mutation id → query key for settled events (key not provided by interface)
  final _mutationKeys = <String, String>{};

  // Start timestamps (ms since epoch) for in-flight fetches and mutations.
  final _fetchStartMs = <String, int>{};
  final _mutationStartMs = <String, int>{};

  // First-seen timestamp per query key (ms since epoch).
  final _queryCreatedAt = <String, int>{};

  bool _disposed = false;

  // ── Public streams ──────────────────────────────────────────────────────────

  Stream<QueryEvent> get onQuery => _queryController.stream;
  Stream<MutationEvent> get onMutation => _mutationController.stream;
  Stream<TimelineEvent> get onTimeline => _timelineController.stream;

  // ── Synchronous snapshots (for panel initialisation) ────────────────────────

  List<QueryEvent> get queryHistory => List.unmodifiable(_queryHistory);
  List<MutationEvent> get mutationHistory =>
      List.unmodifiable(_mutationHistory);
  List<TimelineEvent> get timelineHistory =>
      List.unmodifiable(_timelineHistory);

  // ── QoraTracker ─────────────────────────────────────────────────────────────

  /// Always `true`: [OverlayTracker] uses the serialized data to populate
  /// the in-app overlay panel's Query Inspector and JSON tree viewer.
  @override
  bool get needsSerialization => true;

  @override
  void onQueryFetching(String key) {
    if (_disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isNew = !_queryCreatedAt.containsKey(key);
    _fetchStartMs[key] = now;
    // Emit a transient loading event so the status dot turns blue immediately.
    // Not recorded in history: the subsequent onQueryFetched event will be.
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
    String? dependsOnKey, // unused: dependency graph lives in the IDE extension
  }) {
    if (_disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // A failed fetch keeps showing the previous data (Failure.previousData,
    // or Success with keepPreviousData); the core reports it without data.
    final isFailure = status?.toString() == 'error';
    final event = QueryEvent.fetched(
      key: key,
      status: status,
      data: isFailure && data == null ? _lastData[key] : data,
      staleTimeMs: staleTimeMs,
      gcTimeMs: gcTimeMs,
      observerCount: observerCount,
      createdAtMs: _createdAt(key, now),
      retryCount: retryCount,
    );
    _pushQuery(event);
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
    _fetchStartMs.remove(key);
    // The core puts back the state from before the fetch: show the last
    // recorded event again, or an idle row if the key never settled.
    final previous = _lastQueryEvent[key];
    if (previous != null) {
      _queryController.add(previous);
    } else {
      _pushQuery(QueryEvent(
        eventId: QoraEvent.generateId(),
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        type: QueryEventType.updated,
        key: key,
        status: 'idle',
        createdAtMs: _queryCreatedAt[key],
      ));
    }
    _emitTimeline(TimelineEventType.queryCancelled, key);
  }

  @override
  void onQueryRemoved(String key) {
    if (_disposed) return;
    _queryCreatedAt.remove(key);
    _lastQueryEvent.remove(key);
    _lastData.remove(key);
    _fetchStartMs.remove(key);
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
    _pushQuery(
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
    _pushQuery(
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
    final event = MutationEvent.started(id: id, key: key, variables: variables);
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
      key.isEmpty ? null : key,
      id: id,
      duration: duration,
    );
  }

  /// Called by `setQueryData`: a cache write, optimistic or not.
  ///
  /// It shows as a row with the written data. A mutation is never labelled
  /// optimistic from it: `setQueryData` does not say why it was called.
  @override
  void onOptimisticUpdate(String key, Object? optimisticData) {
    if (_disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = _lastQueryEvent[key];
    _pushQuery(QueryEvent(
      eventId: QoraEvent.generateId(),
      timestampMs: now,
      type: QueryEventType.updated,
      key: key,
      status: 'success',
      data: optimisticData,
      staleTimeMs: previous?.staleTimeMs,
      gcTimeMs: previous?.gcTimeMs,
      observerCount: previous?.observerCount ?? 0,
      createdAtMs: _createdAt(key, now),
    ));
    _emitTimeline(TimelineEventType.optimisticUpdate, key);
  }

  @override
  void onCacheCleared() {
    if (_disposed) return;
    // clear() reports no per-key removal: remove every row seen so far.
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final key in {..._queryCreatedAt.keys, ..._lastQueryEvent.keys}) {
      _push(
        _queryHistory,
        _queryController,
        QueryEvent(
          eventId: QoraEvent.generateId(),
          timestampMs: now,
          type: QueryEventType.removed,
          key: key,
        ),
      );
    }
    _lastQueryEvent.clear();
    _lastData.clear();
    _queryCreatedAt.clear();
    _fetchStartMs.clear();
    _mutationKeys.clear();
    _emitTimeline(TimelineEventType.cacheCleared, null);
  }

  @override
  void dispose() {
    _disposed = true;
    _queryController.close();
    _mutationController.close();
    _timelineController.close();
    _queryHistory.clear();
    _mutationHistory.clear();
    _timelineHistory.clear();
    _lastQueryEvent.clear();
    _lastData.clear();
    _mutationKeys.clear();
    _queryCreatedAt.clear();
    _fetchStartMs.clear();
    _mutationStartMs.clear();
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

  void _pushQuery(QueryEvent event) {
    _lastQueryEvent[event.key] = event;
    if (event.status == 'success') _lastData[event.key] = event.data;
    _push(_queryHistory, _queryController, event);
  }

  void _push<T>(ListQueue<T> buf, StreamController<T> ctrl, T event) {
    if (buf.length >= _kMaxEvents) buf.removeFirst();
    buf.addLast(event);
    ctrl.add(event);
  }
}
