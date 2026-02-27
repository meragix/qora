
import 'dart:async';
import 'dart:collection';

import 'package:qora/qora.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart' hide MutationEvent;

class OverlayTracker implements QoraTracker {
  static const int _kMaxEvents = 200;

  final _queryController      = StreamController<QueryEvent>.broadcast();
  final _mutationController   = StreamController<MutationEvent>.broadcast();
  final _optimisticController = StreamController<OptimisticEvent>.broadcast();
  final _timelineController   = StreamController<TimelineEvent>.broadcast();

  // Ring-buffers — mémoire bornée, O(1)
  final _queryHistory    = ListQueue<QueryEvent>(_kMaxEvents);
  final _mutationHistory = ListQueue<MutationEvent>(_kMaxEvents);
  final _timelineHistory = ListQueue<TimelineEvent>(_kMaxEvents);

  // État courant du cache (key → snapshot)
  final _cacheState = <String, QuerySnapshot>{};

  // Streams publics
  Stream<QueryEvent>      get onQuery      => _queryController.stream;
  Stream<MutationEvent>   get onMutation   => _mutationController.stream;
  Stream<OptimisticEvent> get onOptimistic => _optimisticController.stream;
  Stream<TimelineEvent>   get onTimeline   => _timelineController.stream;

  // Snapshots synchrones pour l'initialisation des panels
  List<QueryEvent>           get queryHistory    => List.unmodifiable(_queryHistory);
  List<MutationEvent>        get mutationHistory => List.unmodifiable(_mutationHistory);
  List<TimelineEvent>        get timelineHistory => List.unmodifiable(_timelineHistory);
  Map<String, QuerySnapshot> get cacheSnapshot   => Map.unmodifiable(_cacheState);

  bool _disposed = false;

  @override
  void onQueryFetched(String key, Object? data, QueryStatus status) {
    if (_disposed) return;
    final event = QueryEvent.fetched(key: key, status: status, timestamp: DateTime.now());
    _push(_queryHistory, _queryController, event);
    _cacheState[key] = QuerySnapshot(
      key: key, status: status,
      updatedAt: DateTime.now(),
      dataPreview: _truncate(data), updatedAtMs: null,
    );
    _emitTimeline(TimelineEventType.fetchStarted, key);
  }

  @override
  void onMutationStarted(String id, String key, Object? variables) {
    if (_disposed) return;
    final event = MutationEvent.started(
      id: id, key: key,
      variablesPreview: _truncate(variables),
      timestamp: DateTime.now(),
    );
    _push(_mutationHistory, _mutationController, event);
    _emitTimeline(TimelineEventType.mutationStarted, key, id: id);
  }

  @override
  void onMutationSettled(String id, bool success, Object? result) {
    if (_disposed) return;
    final event = MutationEvent.settled(
      id: id, success: success,
      resultPreview: _truncate(result),
      timestamp: DateTime.now(),
    );
    _push(_mutationHistory, _mutationController, event);
    _emitTimeline(
      success ? TimelineEventType.mutationSuccess : TimelineEventType.mutationError,
      null, id: id,
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
    _emitTimeline(TimelineEventType.cacheCleared, null);
  }

  void _emitTimeline(TimelineEventType type, String? key, {String? id}) {
    final event = TimelineEvent(
      type: type, key: key, mutationId: id,
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
  }
}