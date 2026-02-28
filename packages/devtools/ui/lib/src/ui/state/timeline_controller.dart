import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/usecases/observe_events.dart';
import 'package:qora_devtools_ui/src/domain/usecases/refetch_query.dart';

/// UI controller that keeps a capped in-memory timeline of protocol events.
///
/// [TimelineController] subscribes to the [ObserveEventsUseCase] stream and
/// accumulates [QoraEvent] instances in a bounded list. It is the single
/// source of truth for the timeline panel and drives the refetch action.
///
/// ## Memory cap
///
/// The timeline is capped at [maxEvents] entries (default 500). When the limit
/// is reached, the oldest event is evicted (FIFO) before adding the new one.
/// This prevents unbounded memory growth in long-running debug sessions.
///
/// Tune [maxEvents] based on the target use-case:
/// - **Inspector sessions** (short, high-frequency): lower (100–200).
/// - **Performance audits** (long, low-frequency): higher (1000+).
///
/// ## Ordering
///
/// [events] returns events **most recent first** (reversed insertion order)
/// so that the timeline list view scrolls from the top to show the latest
/// activity immediately.
///
/// ## Lifecycle
///
/// Call [start] once after the widget mounts to begin event accumulation.
/// [dispose] cancels the stream subscription and must be called when the
/// owning `StatefulWidget` is removed from the tree.
class TimelineController extends ChangeNotifier {
  /// Creates a timeline controller.
  ///
  /// [observeEvents] — use-case providing the live event stream.
  /// [refetchQuery] — use-case dispatching refetch commands.
  /// [maxEvents] — maximum events retained before FIFO eviction.
  TimelineController({
    required ObserveEventsUseCase observeEvents,
    required RefetchQueryUseCase refetchQuery,
    this.maxEvents = 500,
  })  : _observeEvents = observeEvents,
        _refetchQuery = refetchQuery;

  final ObserveEventsUseCase _observeEvents;
  final RefetchQueryUseCase _refetchQuery;

  /// Maximum number of events retained; oldest are evicted first.
  final int maxEvents;

  final List<QoraEvent> _events = <QoraEvent>[];
  StreamSubscription<QoraEvent>? _subscription;

  /// Unmodifiable snapshot of timeline events, **most recent first**.
  List<QoraEvent> get events => List<QoraEvent>.unmodifiable(_events.reversed);

  /// Starts consuming the [ObserveEventsUseCase] stream.
  ///
  /// Idempotent — calling [start] a second time has no effect if a
  /// subscription is already active.
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
