import 'package:flutter/foundation.dart';
import 'package:qora_devtools_ui/src/domain/entities/mutation_detail.dart';

/// Domain state holder for the currently selected mutation in the Mutation
/// Inspector detail panel.
///
/// [MutationInspectorNotifier] follows a **single-selection** model: at most
/// one [MutationDetail] is displayed at a time.  It is intentionally separate
/// from [MutationsNotifier] (which owns the list) so that:
///
/// - Selecting a row does **not** trigger a rebuild of the full mutation list.
/// - The inspector panel widget subscribes only to this notifier, keeping its
///   rebuild scope narrow.
///
/// ## State machine
///
/// ```
/// null (no selection) ──select(detail)──▶ MutationDetail displayed
///         ▲                                        │
///         └──────────select(null)──────────────────┘
/// ```
///
/// [select] with `null` closes the inspector panel (e.g. when the user clicks
/// elsewhere or the mutation list is cleared).
///
/// ## Rollback integration
///
/// When [selected] is non-null and `selected.rollbackContext != null`, the
/// inspector panel surfaces a **"Rollback"** button.  Tapping it dispatches
/// [RollbackOptimisticCommand] via the appropriate use-case.
class MutationInspectorNotifier extends ChangeNotifier {
  MutationDetail? _selected;

  /// The currently displayed [MutationDetail], or `null` when no mutation is
  /// selected.
  MutationDetail? get selected => _selected;

  /// Sets [detail] as the selected mutation and notifies listeners.
  ///
  /// Pass `null` to deselect (close the inspector panel).
  void select(MutationDetail? detail) {
    _selected = detail;
    notifyListeners();
  }
}
