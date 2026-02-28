import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/data/overlay_tracker.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Maintains the current set of observed mutations for the Mutations panel.
///
/// Listens to [OverlayTracker.onMutation] and keeps a map of
/// mutation id → latest [MutationEvent], so that multiple events for the
/// same mutation (started → settled) are collapsed into a single row.
class MutationsNotifier extends ChangeNotifier {
  final OverlayTracker _tracker;
  late final StreamSubscription<MutationEvent> _sub;

  /// mutation id → latest MutationEvent
  final _mutations = <String, MutationEvent>{};

  MutationsNotifier(this._tracker) {
    for (final e in _tracker.mutationHistory) {
      _mutations[e.id] = e;
    }
    _sub = _tracker.onMutation.listen((event) {
      _mutations[event.id] = event;
      notifyListeners();
    });
  }

  /// All observed mutations, one entry per distinct mutation id.
  ///
  /// Ordered by insertion time (oldest first). The UI may reverse this list.
  List<MutationEvent> get mutations => _mutations.values.toList();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
