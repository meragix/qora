import 'package:flutter/foundation.dart';
import 'package:qora_devtools_ui/src/domain/entities/timeline_event.dart';

/// State holder for timeline list, pause, and filter controls.
class TimelineNotifier extends ChangeNotifier {
  final List<TimelineEventView> _events = <TimelineEventView>[];
  bool _paused = false;
  String _filter = '';

  /// Current timeline events.
  List<TimelineEventView> get events =>
      List<TimelineEventView>.unmodifiable(_events);

  /// Whether timeline updates are paused.
  bool get paused => _paused;

  /// Current text filter.
  String get filter => _filter;

  /// Adds one timeline event unless paused.
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
