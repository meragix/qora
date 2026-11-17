import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:qora/qora.dart';

/// The calls of [QoraClient.mutationQueue], for the Queue tab.
///
/// Reads the queue itself, not tracker events: what the tab shows is what
/// the queue holds, including calls restored by `PersistQoraClient.hydrate()`
/// before the overlay was mounted.
class MutationQueueNotifier extends ChangeNotifier {
  /// Watches [queue]; with `null` (no client passed to the overlay) the tab
  /// explains how to enable it.
  MutationQueueNotifier(this._queue) {
    final queue = _queue;
    if (queue == null) return;
    _entries = queue.entries;
    _sub = queue.entriesStream.listen((entries) {
      _entries = entries;
      notifyListeners();
    });
  }

  final MutationQueue? _queue;
  StreamSubscription<List<QueuedMutation>>? _sub;
  List<QueuedMutation> _entries = const [];
  String? _selectedId;

  /// Whether the overlay received a client, so the queue can be read.
  bool get isAvailable => _queue != null;

  /// The queued calls, in the order they were made.
  List<QueuedMutation> get entries => _entries;

  /// The `mutationId` of the selected call.
  String? get selectedId => _selectedId;

  /// The selected call, or `null` when none is selected or it left the
  /// queue (sent, or discarded by the app).
  QueuedMutation? get selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final e in _entries) {
      if (e.mutationId == id) return e;
    }
    return null;
  }

  /// Selects [entry] for the inspector.
  void select(QueuedMutation entry) {
    _selectedId = entry.mutationId;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
