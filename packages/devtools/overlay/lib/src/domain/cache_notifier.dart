import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/data/overlay_tracker.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Exposes the current cache snapshot from [OverlayTracker] as a reactive
/// [ChangeNotifier].
///
/// Notifies listeners whenever a query is fetched or the cache is cleared,
/// so the Cache panel stays in sync without polling.
class CacheNotifier extends ChangeNotifier {
  final OverlayTracker _tracker;
  late final StreamSubscription<QueryEvent> _querySub;
  late final StreamSubscription<OptimisticEvent> _optimisticSub;

  CacheNotifier(this._tracker) {
    // Rebuild on every query fetch.
    _querySub = _tracker.onQuery.listen((_) => notifyListeners());
    // Rebuild when an optimistic write happens (also changes the snapshot).
    _optimisticSub = _tracker.onOptimistic.listen((_) => notifyListeners());
  }

  /// Current key → [QuerySnapshot] map from the tracker.
  Map<String, QuerySnapshot> get snapshot => _tracker.cacheSnapshot;

  @override
  void dispose() {
    _querySub.cancel();
    _optimisticSub.cancel();
    super.dispose();
  }
}
