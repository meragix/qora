import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/data/overlay_tracker.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class TimelineNotifier extends ChangeNotifier {
  final OverlayTracker _tracker;
  late final StreamSubscription<TimelineEvent> _sub;

  final _events = <TimelineEvent>[];
  bool _paused = false;
  String _filter = '';

  bool get paused => _paused;
  String get filter => _filter;

  List<TimelineEvent> get filteredEvents {
    final reversed = _events.reversed.toList();
    if (_filter.isEmpty) return reversed;
    return reversed.where((e) =>
        (e.key?.contains(_filter) ?? false) ||
        e.type.name.toLowerCase().contains(_filter.toLowerCase()),
    ).toList();
  }

  TimelineNotifier(this._tracker) {
    _events.addAll(_tracker.timelineHistory);
    _sub = _tracker.onTimeline.listen((event) {
      if (_paused) return;
      _events.add(event);
      if (_events.length > 200) _events.removeAt(0);
      notifyListeners();
    });
  }

  void togglePause() { _paused = !_paused; notifyListeners(); }
  void setFilter(String v) { _filter = v; notifyListeners(); }
  void clear() { _events.clear(); notifyListeners(); }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}