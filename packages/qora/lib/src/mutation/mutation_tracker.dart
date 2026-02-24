import 'package:qora/src/mutation/mutation_state.dart';

/// Interface that receives mutation lifecycle notifications from a
/// [MutationController].
///
/// [QoraClient] implements this interface to maintain a global snapshot of
/// active mutations and a real-time event stream — enabling DevTools and
/// global error handlers to observe all mutations without coupling
/// [MutationController] to [QoraClient] directly.
///
/// ## Why an interface and not a direct reference?
///
/// [MutationController] lives in `mutation/` and must not import `QoraClient`
/// (which imports from `cache/`, `config/`, etc.). The [MutationTracker]
/// interface breaks the potential circular dependency:
///
/// ```
/// mutation_tracker.dart  ←── mutation_controller.dart
///        ↓
/// qora_client.dart (implements MutationTracker)
/// ```
///
/// ## Custom implementations
///
/// You can implement [MutationTracker] to build your own DevTools, logging
/// middleware, or testing spies:
///
/// ```dart
/// class MutationLogger implements MutationTracker {
///   @override
///   void trackMutation<TData, TVariables>(
///     String id,
///     MutationState<TData, TVariables> state,
///   ) => print('[$id] → ${state.runtimeType}');
///
///   @override
///   void untrackMutation(String id) => print('[$id] disposed');
/// }
/// ```
abstract interface class MutationTracker {
  /// Called on every state transition of a [MutationController].
  ///
  /// - Transitioning **to** [MutationIdle] (via [MutationController.reset])
  ///   signals that the controller finished and should be removed from any
  ///   active snapshot.
  /// - All other states (`Pending`, `Success`, `Failure`) signal an active
  ///   or recently completed mutation that should appear in the snapshot.
  void trackMutation<TData, TVariables>(
    String id,
    MutationState<TData, TVariables> state,
  );

  /// Called when a [MutationController] is disposed.
  ///
  /// The controller should be removed from any snapshot silently (no event
  /// emitted — the controller no longer exists).
  void untrackMutation(String id);
}
