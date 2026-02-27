import 'package:flutter/foundation.dart';
import 'package:qora_devtools_ui/src/domain/entities/mutation_detail.dart';

/// State holder for currently selected mutation detail.
class MutationInspectorNotifier extends ChangeNotifier {
  MutationDetail? _selected;

  /// Selected mutation detail.
  MutationDetail? get selected => _selected;

  /// Sets current selected mutation detail.
  void select(MutationDetail? detail) {
    _selected = detail;
    notifyListeners();
  }
}
