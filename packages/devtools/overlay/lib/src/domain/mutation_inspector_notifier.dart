import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qora/qora.dart';
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

  /// mutation id → timestampMs of the original `started` event.
  final _startTimes = <String, int>{};

  /// The currently selected mutation event, or `null` when nothing is selected.
  MutationEvent? get selected => _selected;

  /// View-model for the inspector panel, derived from [selected].
  ///
  /// `null` when [selected] is `null` — the panel renders a placeholder.
  MutationDetail? get detail => _selected == null
      ? null
      : MutationDetail.fromEvent(
          _selected!,
          startedAtMs: _startTimes[_selected!.id],
        );

  MutationInspectorNotifier(this._tracker, {QoraClient? client}) {
    for (final e in _tracker.mutationHistory) {
      if (e.type == MutationEventType.started) _startTimes[e.id] = e.timestampMs;
    }
    _sub = _tracker.onMutation.listen((event) {
      if (event.type == MutationEventType.started) {
        _startTimes[event.id] = event.timestampMs;
      }
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

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Retries the selected mutation.
  ///
  /// Not yet implemented — requires `QoraClient.retryMutation()` support.
  // TODO(overlay): implement retry when the API is available.
  void retry() async {}

  /// Pauses or resumes the selected mutation.
  ///
  /// Not yet implemented — requires `QoraClient.pauseMutation()` and
  /// `QoraClient.resumeMutation()` support.
  // TODO(overlay): implement pause/resume when the API is available.
  void pauseResume() async {}

  /// Cancels the selected mutation.
  ///
  /// Not yet implemented — requires `QoraClient.cancelMutation()` support.
  // TODO(overlay): implement cancel when the API is available.
  void cancel() async {}

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
