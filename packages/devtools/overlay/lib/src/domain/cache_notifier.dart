import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/data/overlay_tracker.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Exposes the current cache snapshot from [OverlayTracker] to the Cache panel.
///
/// The snapshot is updated by [OverlayTracker.onQueryFetched] and cleared by
/// [OverlayTracker.onCacheCleared]. The notifier does not stream individual
/// updates — UI widgets should rebuild by watching [QueriesNotifier] which
/// covers the same source data with richer event detail.
class CacheNotifier extends ChangeNotifier {
  final OverlayTracker _tracker;

  CacheNotifier(this._tracker);

  /// Current key → [QuerySnapshot] map from the tracker.
  Map<String, QuerySnapshot> get snapshot => _tracker.cacheSnapshot;

}
