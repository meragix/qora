import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Domain state holder for the live query list shown in the Queries tab.
///
/// [QueriesNotifier] holds a **snapshot** of all active `QoraClient` cache
/// entries as [QuerySnapshot] objects.  It is updated by [setQueries] whenever
/// the DevTools panel fetches a fresh [CacheSnapshot] via
/// [GetCacheSnapshotCommand].
///
/// ## Snapshot vs. stream semantics
///
/// Unlike [MutationsNotifier] (which accumulates events), [QueriesNotifier]
/// maintains a **current-state** list: each [setQueries] call *replaces* the
/// previous list entirely.  This matches the pull model of the Cache Inspector:
/// each [CacheController.refresh] returns a full point-in-time snapshot.
///
/// ## Active query count badge
///
/// [activeQueryCount] drives the badge on the Queries tab label.  A query is
/// "active" when its status is anything other than `'idle'` (i.e. `'loading'`,
/// `'success'`, `'error'`, `'refreshing'`).
///
/// ## Scaling note
///
/// For apps with hundreds of cache keys the list can become large.  The
/// [QuerySnapshot.data] field is intentionally omitted for large entries by
/// the runtime (lazy chunking), so each item remains lightweight.  If the
/// Queries tab becomes slow, add client-side filtering/sorting before
/// [setQueries] or implement server-side pagination in
/// `getCacheSnapshot`.
class QueriesNotifier extends ChangeNotifier {
  final List<QuerySnapshot> _queryList = <QuerySnapshot>[];

  /// Current snapshot of all active queries, ordered as returned by the
  /// runtime [CacheSnapshot].
  ///
  /// Returns an unmodifiable view; update via [setQueries].
  List<QuerySnapshot> get queryList =>
      List<QuerySnapshot>.unmodifiable(_queryList);

  /// Number of queries whose status is not `'idle'`.
  ///
  /// Used to populate the Queries tab badge and summary indicators.
  int get activeQueryCount =>
      _queryList.where((query) => query.status != 'idle').length;

  /// Replaces the current query list with [items] and notifies listeners.
  ///
  /// Called after each successful [CacheController.refresh]; the previous
  /// list is discarded.  Passing an empty list clears the tab.
  void setQueries(List<QuerySnapshot> items) {
    _queryList
      ..clear()
      ..addAll(items);
    notifyListeners();
  }
}
