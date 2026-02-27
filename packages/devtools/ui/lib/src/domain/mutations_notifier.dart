import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// State holder for mutation list column.
class MutationsNotifier extends ChangeNotifier {
  final List<MutationEvent> _mutations = <MutationEvent>[];

  /// Ordered mutation events.
  List<MutationEvent> get mutations =>
      List<MutationEvent>.unmodifiable(_mutations);

  /// Appends [event] to the mutation list.
  void add(MutationEvent event) {
    _mutations.add(event);
    notifyListeners();
  }

  /// Clears all mutation events.
  void clear() {
    _mutations.clear();
    notifyListeners();
  }
}
