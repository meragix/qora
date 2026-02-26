import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/usecases/observe_events.dart';
import 'package:qora_devtools_ui/src/domain/usecases/refetch_query.dart';

/// UI controller that keeps an in-memory timeline of received protocol events.
class TimelineController extends ChangeNotifier {
  /// Creates a timeline controller.
  TimelineController({
    required ObserveEventsUseCase observeEvents,
    required RefetchQueryUseCase refetchQuery,
    this.maxEvents = 500,
  })  : _observeEvents = observeEvents,
        _refetchQuery = refetchQuery;

  final ObserveEventsUseCase _observeEvents;
  final RefetchQueryUseCase _refetchQuery;
  final int maxEvents;

  final List<QoraEvent> _events = <QoraEvent>[];
  StreamSubscription<QoraEvent>? _subscription;

  /// Snapshot of current timeline events (most recent first).
  List<QoraEvent> get events => List<QoraEvent>.unmodifiable(_events.reversed);

  /// Starts observing the event stream.
  void start() {
    _subscription ??= _observeEvents().listen((event) {
      _events.add(event);
      if (_events.length > maxEvents) {
        _events.removeAt(0);
      }
      notifyListeners();
    });
  }

  /// Clears all currently displayed events.
  void clear() {
    _events.clear();
    notifyListeners();
  }

  /// Sends a refetch command for [queryKey].
  Future<bool> refetch(String queryKey) => _refetchQuery(queryKey);

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
