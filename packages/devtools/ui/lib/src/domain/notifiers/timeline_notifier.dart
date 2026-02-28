import 'package:flutter/foundation.dart';
import 'package:qora_devtools_ui/src/domain/entities/timeline_event.dart';

/// Domain-layer state holder for the timeline list, pause, and filter controls.
///
/// [TimelineNotifier] is a pure Flutter-free `ChangeNotifier` owned by the
/// domain layer. It accumulates [TimelineEventView] rows in insertion order
/// and exposes pause / filter controls that the UI maps to toolbar buttons.
///
/// ## Scaling note
///
/// [TimelineNotifier] has no built-in cap on [events] length. For long-running
/// debug sessions with many events, the list can grow unboundedly. Either:
/// - apply a cap here (e.g. drop the oldest entry when length > N), or
/// - rely on [TimelineController] (which caps at [TimelineController.maxEvents])
///   and pass only view-model rows to this notifier.
///
/// ## Pause semantics
///
/// When [paused] is `true`, [add] silently discards incoming events. This
/// allows a developer to "freeze" the timeline for inspection without
/// disconnecting the event stream. Events emitted during the pause are **lost**
/// — they are not buffered or replayed on resume.
class TimelineNotifier extends ChangeNotifier {
  final List<TimelineEventView> _events = <TimelineEventView>[];
  bool _paused = false;
  String _filter = '';

  /// Unmodifiable snapshot of current timeline rows, in insertion order.
  List<TimelineEventView> get events =>
      List<TimelineEventView>.unmodifiable(_events);

  /// `true` when the timeline is paused — new [add] calls are no-ops.
  bool get paused => _paused;

  /// Current case-insensitive text filter applied by the timeline panel.
  String get filter => _filter;

  /// Appends [event] to the timeline unless [paused].
  ///
  /// Events discarded while paused are **not** buffered.
  void add(TimelineEventView event) {
    if (_paused) return;
    _events.add(event);
    notifyListeners();
  }

  /// Toggles pause state.
  void togglePause() {
    _paused = !_paused;
    notifyListeners();
  }

  /// Updates text filter.
  void setFilter(String value) {
    _filter = value;
    notifyListeners();
  }

  /// Clears timeline events.
  void clear() {
    _events.clear();
    notifyListeners();
  }
}
