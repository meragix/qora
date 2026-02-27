import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// State holder for the QUERIES tab.
class QueriesNotifier extends ChangeNotifier {
  final List<QuerySnapshot> _queryList = <QuerySnapshot>[];

  /// Snapshot list shown in queries tab.
  List<QuerySnapshot> get queryList =>
      List<QuerySnapshot>.unmodifiable(_queryList);

  /// Number of queries marked active (non-idle).
  int get activeQueryCount =>
      _queryList.where((query) => query.status != 'idle').length;

  /// Replaces the query list with [items].
  void setQueries(List<QuerySnapshot> items) {
    _queryList
      ..clear()
      ..addAll(items);
    notifyListeners();
  }
}
