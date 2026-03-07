import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/data/overlay_tracker.dart';
import 'package:qora_devtools_overlay/src/domain/query_detail.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Manages the selected mutation for the Inspector column (column 2).
///
/// The list column (column 1) calls [select] when the user taps a mutation row.
/// The inspector panel reads [detail] to render STATUS / VARIABLES / ERROR /
/// ROLLBACK CONTEXT / METADATA sections.
///
/// Auto-updates when a new [QueryEvent] with the same [QueryEvent.id]
/// arrives (e.g. retry settled), keeping the inspector in sync without
/// requiring the user to re-tap.
class QueryInspectorNotifier extends ChangeNotifier {
  final OverlayTracker _tracker;
  late final StreamSubscription<QueryEvent> _sub;

  QueryEvent? _selected;

  /// The currently selected mutation event, or `null` when nothing is selected.
  QueryEvent? get selected => _selected;

  /// View-model for the inspector panel, derived from [selected].
  ///
  /// `null` when [selected] is `null` — the panel renders a placeholder.
  QueryDetail? get detail =>
      _selected == null ? null : QueryDetail.fromEvent(_selected!);

  QueryInspectorNotifier(this._tracker) {
    _sub = _tracker.onQuery.listen((event) {
      // Auto-update if the selected mutation changes state (e.g. retry settled)
      if (_selected != null && event.eventId == _selected!.eventId) {
        _selected = event;
        notifyListeners();
      }
    });
  }

  /// Selects [mutation] for inspection; triggers a panel rebuild.
  void select(QueryEvent query) {
    _selected = query;
    notifyListeners();
  }

  //todo: implement actions logic for queries when supported by QoraClient (e.g. refetch, cancel)

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
