import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/data/overlay_tracker.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class MutationInspectorNotifier extends ChangeNotifier {
  final OverlayTracker _tracker;
  final QueryClient _client;
  late final StreamSubscription<MutationEvent> _sub;

  MutationEvent? _selected;
  MutationEvent? get selected => _selected;
  MutationDetail? get detail => _selected == null ? null : MutationDetail.fromEvent(_selected!);

  MutationInspectorNotifier(this._tracker, this._client) {
    _sub = _tracker.onMutation.listen((event) {
      // Auto-update si la mutation sélectionnée change d'état (ex: retry settled)
      if (_selected != null && event.id == _selected!.id) {
        _selected = event;
        notifyListeners();
      }
    });
  }

  void select(MutationEvent mutation) {
    _selected = mutation;
    notifyListeners();
  }

  Future<void> retry() async {
    if (_selected == null) return;
    await _client.retryMutation(_selected!.id);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
