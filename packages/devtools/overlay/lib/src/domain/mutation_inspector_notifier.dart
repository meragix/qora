import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/data/overlay_tracker.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_detail.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Manages the selected mutation for the Inspector column (column 2).
///
/// The list column (column 1) calls [select] when the user taps a mutation row.
/// The inspector panel reads [detail] to render STATUS / VARIABLES / ERROR /
/// ROLLBACK CONTEXT / METADATA sections.
///
/// Auto-updates when a new [MutationEvent] with the same [MutationEvent.id]
/// arrives (e.g. retry settled), keeping the inspector in sync without
/// requiring the user to re-tap.
class MutationInspectorNotifier extends ChangeNotifier {
  final OverlayTracker _tracker;
  late final StreamSubscription<MutationEvent> _sub;

  MutationEvent? _selected;

  /// The currently selected mutation event, or `null` when nothing is selected.
  MutationEvent? get selected => _selected;

  /// View-model for the inspector panel, derived from [selected].
  ///
  /// `null` when [selected] is `null` — the panel renders a placeholder.
  MutationDetail? get detail =>
      _selected == null ? null : MutationDetail.fromEvent(_selected!);

  MutationInspectorNotifier(this._tracker) {
    _sub = _tracker.onMutation.listen((event) {
      // Auto-update if the selected mutation changes state (e.g. retry settled)
      if (_selected != null && event.id == _selected!.id) {
        _selected = event;
        notifyListeners();
      }
    });
  }

  /// Selects [mutation] for inspection; triggers a panel rebuild.
  void select(MutationEvent mutation) {
    _selected = mutation;
    notifyListeners();
  }

  /// Retries the selected mutation.
  ///
  /// Not yet implemented — requires `QoraClient.retryMutation()` support.
  // TODO(overlay): implement retry via QoraClient when the API is available.
  Future<void> retry() async {}

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
