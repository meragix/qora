import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_qora/flutter_qora.dart';

/// Groups the current [MutationState] and the action callbacks returned by
/// [useMutation].
///
/// Access the state via the typed helpers ([isIdle], [isPending], etc.) or
/// pattern-match [state] directly.
///
/// ```dart
/// final mutation = useMutation<User, UpdateUserInput>(
///   mutator: (input) => api.updateUser(input),
/// );
///
/// // Fire-and-forget — errors are captured in MutationFailure state.
/// mutation.mutate(UpdateUserInput(name: 'Alice'));
///
/// // Await the result — errors are propagated via the returned Future.
/// final user = await mutation.mutateAsync(UpdateUserInput(name: 'Alice'));
/// ```
class MutationHandle<TData, TVariables> {
  /// The current state of this mutation.
  final MutationState<TData, TVariables> state;

  /// Triggers the mutation. Errors are silenced and captured in
  /// [MutationFailure] state.
  final void Function(TVariables variables) mutate;

  /// Triggers the mutation and returns the result. Errors are propagated.
  final Future<TData?> Function(TVariables variables) mutateAsync;

  /// Resets the mutation back to [MutationIdle].
  final void Function() reset;

  /// `true` when no mutation has run yet (or after [reset]).
  bool get isIdle => state.isIdle;

  /// `true` while the mutation is actively running.
  bool get isPending => state.isPending;

  /// `true` after the mutation completed successfully.
  bool get isSuccess => state.isSuccess;

  /// `true` after the mutation failed.
  bool get isError => state.isError;

  /// The result data if the mutation succeeded, otherwise `null`.
  TData? get data => state.dataOrNull;

  /// The error if the mutation failed, otherwise `null`.
  Object? get error => state.errorOrNull;

  const MutationHandle({
    required this.state,
    required this.mutate,
    required this.mutateAsync,
    required this.reset,
  });
}

/// Hook for triggering a mutation and tracking its lifecycle state.
///
/// Creates a [MutationController] on the first render and disposes it when
/// the widget is unmounted. The [MutationHandle.state] is updated on every
/// state transition.
///
/// [TContext] defaults to `void` — supply an explicit type argument when you
/// need to store an optimistic-update snapshot for rollback via [onMutate].
///
/// ```dart
/// class EditProfileScreen extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final mutation = useMutation<User, UpdateUserInput>(
///       mutator: (input) => Api.updateUser(input),
///       options: MutationOptions(
///         onSuccess: (user, _, __) async {
///           QoraScope.of(context).invalidate(['users', user.id]);
///         },
///       ),
///     );
///
///     return ElevatedButton(
///       onPressed: mutation.isPending
///           ? null
///           : () => mutation.mutate(UpdateUserInput(name: 'Alice')),
///       child: mutation.isPending
///           ? const CircularProgressIndicator()
///           : const Text('Save'),
///     );
///   }
/// }
/// ```
MutationHandle<TData, TVariables> useMutation<TData, TVariables>({
  required Future<TData> Function(TVariables variables) mutator,
  MutationOptions<TData, TVariables, void>? options,
}) {
  final state = useState<MutationState<TData, TVariables>>(
    MutationIdle<TData, TVariables>(),
  );

  // Create the controller once for the lifetime of the widget.
  final controller = useMemoized(
    () => MutationController<TData, TVariables, void>(
      mutator: mutator,
      options: options,
    ),
    [mutator], // Recreates the controller if the mutator function changes
  );

  // Subscribe to state changes.
  useEffect(() {
    final sub = controller.stream.listen((s) => state.value = s);
    return sub.cancel;
  }, [controller]);

  // Dispose when the widget is unmounted.
  useEffect(() => controller.dispose, [controller]);

  return MutationHandle<TData, TVariables>(
    state: state.value,
    mutate: (variables) => controller.mutate(variables),
    mutateAsync: controller.mutate,
    reset: controller.reset,
  );
}
