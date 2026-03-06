import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/data/overlay_tracker.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Maintains the current set of observed queries for the Queries panel.
///
/// Listens to [OverlayTracker.onQuery] and keeps a map of key → latest
/// [QueryEvent]. The panel header badge uses [activeQueryCount] to show
/// how many queries are currently in a loading state.
class QueriesNotifier extends ChangeNotifier {
  Timer? _ticker;
  final OverlayTracker _tracker;
  late final StreamSubscription<QueryEvent> _sub;

  /// key → latest QueryEvent for that key
  final _queries = <String, QueryEvent>{};

  QueriesNotifier(this._tracker) {
    for (final e in _tracker.queryHistory) {
      _queries[e.key] = e;
    }
    _sub = _tracker.onQuery.listen((event) {
      _queries[event.key] = event;
      notifyListeners();
    });
    // _startTicking();
  }

  void _startTicking() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_queries.isNotEmpty) {
        notifyListeners();
      }
    });
  }

  /// All observed queries, one entry per distinct key.
  List<QueryEvent> get queries {
    return _queries.values.toList()..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
  }

  /// Number of queries whose last known status is `'loading'`.
  int get activeQueryCount => _queries.values.where((e) => e.status == 'loading').length;

  @override
  void dispose() {
    _ticker?.cancel();
    _sub.cancel();
    super.dispose();
  }
}
