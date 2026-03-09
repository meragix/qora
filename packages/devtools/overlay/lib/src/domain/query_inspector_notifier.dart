import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qora/qora.dart';
import 'package:qora_devtools_overlay/src/data/overlay_tracker.dart';
import 'package:qora_devtools_overlay/src/domain/query_detail.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Manages the selected query for the Inspector column (column 2).
///
/// The list column calls [select] when the user taps a query row.
/// When a [QoraClient] is provided, the action methods (refetch, invalidate,
/// remove, markStale, simulateError) operate directly on the live cache.
class QueryInspectorNotifier extends ChangeNotifier {
  final OverlayTracker _tracker;
  final QoraClient? _client;
  late final StreamSubscription<QueryEvent> _sub;

  QueryEvent? _selected;

  /// Sticky flag: `true` from the moment the selected query is invalidated
  /// until a non-loading fetch result (success or error) clears it.
  ///
  /// Tracked separately because `invalidate()` triggers an immediate refetch
  /// that replaces the `invalidated` event before the UI can render it.
  bool _isInvalidated = false;

  /// The currently selected query event, or `null` when nothing is selected.
  QueryEvent? get selected => _selected;

  /// View-model for the inspector panel, derived from [selected].
  QueryDetail? get detail => _selected == null
      ? null
      : QueryDetail.fromEvent(_selected!, isInvalidated: _isInvalidated);

  /// Whether action buttons should be enabled.
  bool get hasClient => _client != null;

  QueryInspectorNotifier(this._tracker, {QoraClient? client}) : _client = client {
    _sub = _tracker.onQuery.listen((event) {
      if (_selected == null || event.key != _selected!.key) return;
      if (event.type == QueryEventType.removed) {
        _selected = null;
        _isInvalidated = false;
      } else {
        if (event.type == QueryEventType.invalidated) {
          _isInvalidated = true;
        } else if (event.type == QueryEventType.fetched &&
            event.status != 'loading') {
          _isInvalidated = false;
        }
        _selected = event;
      }
      notifyListeners();
    });
  }

  /// Selects [query] for inspection; triggers a panel rebuild.
  void select(QueryEvent query) {
    _selected = query;
    notifyListeners();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Marks the selected query stale, causing active observers to refetch.
  void refetch() => _withKey(_client!.invalidate);

  /// Marks the selected query as stale (same effect as [refetch] in Qora).
  void invalidate() => _withKey(_client!.invalidate);

  /// Removes the selected query from the cache entirely.
  void remove() => _withKey(_client!.removeQuery);

  /// Marks the selected query stale without triggering an immediate refetch.
  ///
  /// Unlike [invalidate], this does not push a [Loading] state to active
  /// observers. The query will be revalidated in the background on its next
  /// access (mount or explicit fetch).
  void markStale() => _withKey(_client!.markStale);

  /// Forces the selected query into a [Failure] state for testing.
  void simulateError() {
    if (_selected == null || _client == null) return;
    _client.debugSetQueryError(
      _parsedKey(_selected!.key),
      Exception('Simulated error from DevTools'),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Decodes the JSON-serialised key back to a Dart object so that
  /// [QoraClient.normalizeKey] can process it correctly.
  Object _parsedKey(String serialized) {
    try {
      return jsonDecode(serialized) as Object;
    } catch (_) {
      return serialized;
    }
  }

  void _withKey(void Function(Object) action) {
    if (_selected == null || _client == null) return;
    action(_parsedKey(_selected!.key));
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
