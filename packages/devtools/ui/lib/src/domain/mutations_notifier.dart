import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Domain state holder for the chronological list of mutation events shown in
/// the Mutations tab.
///
/// [MutationsNotifier] is a [ChangeNotifier] that accumulates [MutationEvent]s
/// as they arrive from the runtime push stream.  The Mutations tab subscribes
/// as a listener and rebuilds whenever the list changes.
///
/// ## Event ordering
///
/// Events are stored in **arrival order** (append-only).  The list therefore
/// reflects the chronological mutation history for the current DevTools
/// session.  Correlation across lifecycle phases (`started` → `settled`) is
/// done by [MutationEvent.id] rather than list position.
///
/// ## Memory / scaling note
///
/// The internal list is **unbounded**.  In long-lived sessions with frequent
/// mutations the list can grow large.  [clear] resets it; consider adding a
/// configurable cap (similar to [TimelineController.maxEvents]) if memory
/// pressure becomes an issue.
///
/// ## Relationship to [MutationInspectorNotifier]
///
/// [MutationsNotifier] owns the **list** of mutations.
/// [MutationInspectorNotifier] owns the **selected item** detail panel.
/// They are separate notifiers to avoid spurious rebuilds: selecting a row
/// does not invalidate the entire list widget.
class MutationsNotifier extends ChangeNotifier {
  final List<MutationEvent> _mutations = <MutationEvent>[];

  /// Chronologically ordered list of [MutationEvent]s accumulated since the
  /// DevTools panel connected (or since the last [clear]).
  ///
  /// Returns an unmodifiable view; modify via [add] or [clear].
  List<MutationEvent> get mutations =>
      List<MutationEvent>.unmodifiable(_mutations);

  /// Appends [event] to the end of the mutation list and notifies listeners.
  ///
  /// Called by the event subscription in the main controller whenever a
  /// [MutationEvent] arrives on the push stream.
  void add(MutationEvent event) {
    _mutations.add(event);
    notifyListeners();
  }

  /// Removes all mutation events and notifies listeners.
  ///
  /// Typically wired to a **"Clear"** button in the Mutations tab toolbar.
  void clear() {
    _mutations.clear();
    notifyListeners();
  }
}
