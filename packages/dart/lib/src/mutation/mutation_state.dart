import 'package:meta/meta.dart';

/// Represents the state of a mutation operation.
///
/// A mutation can be in one of four states:
/// - [MutationIdle]: No mutation has run yet (or after [MutationController.reset])
/// - [MutationPending]: Mutation is actively running
/// - [MutationSuccess]: Mutation completed successfully
/// - [MutationFailure]: Mutation failed
///
/// Use pattern matching to handle all states exhaustively:
///
/// ```dart
/// switch (state) {
///   case MutationIdle():
///     return ElevatedButton(
///       onPressed: () => mutate(variables),
///       child: const Text('Submit'),
///     );
///   case MutationPending():
///     return const CircularProgressIndicator();
///   case MutationSuccess(:final data):
///     return Text('Done: $data');
///   case MutationFailure(:final error):
///     return Text('Error: $error');
/// }
/// ```
@immutable
sealed class MutationState<TData, TVariables> {
  const MutationState();

  /// Returns true if no mutation has been run (or after reset).
  bool get isIdle => this is MutationIdle<TData, TVariables>;

  /// Returns true if a mutation is actively running.
  bool get isPending => this is MutationPending<TData, TVariables>;

  /// Returns true if the last mutation completed successfully.
  bool get isSuccess => this is MutationSuccess<TData, TVariables>;

  /// Returns true if the last mutation failed.
  bool get isError => this is MutationFailure<TData, TVariables>;

  /// The result data if the mutation succeeded, otherwise null.
  TData? get dataOrNull => switch (this) {
        MutationSuccess(:final data) => data,
        _ => null,
      };

  /// The error if the mutation failed, otherwise null.
  Object? get errorOrNull => switch (this) {
        MutationFailure(:final error) => error,
        _ => null,
      };

  /// The variables used in the last mutation call, or null if idle.
  TVariables? get variablesOrNull => switch (this) {
        MutationPending(:final variables) => variables,
        MutationSuccess(:final variables) => variables,
        MutationFailure(:final variables) => variables,
        _ => null,
      };

  /// Executes a callback based on the current state.
  ///
  /// All callbacks are optional. Nothing happens for unhandled states.
  void when({
    void Function()? onIdle,
    void Function(TVariables variables)? onPending,
    void Function(TData data, TVariables variables)? onSuccess,
    void Function(
      Object error,
      StackTrace? stackTrace,
      TVariables variables,
    )? onError,
  }) {
    switch (this) {
      case MutationIdle():
        onIdle?.call();
      case MutationPending(:final variables):
        onPending?.call(variables);
      case MutationSuccess(:final data, :final variables):
        onSuccess?.call(data, variables);
      case MutationFailure(:final error, :final stackTrace, :final variables):
        onError?.call(error, stackTrace, variables);
    }
  }

  /// Maps the state to a value of type [R].
  ///
  /// [orElse] is used as a fallback for any unhandled state.
  ///
  /// ```dart
  /// final label = state.maybeWhen(
  ///   onSuccess: (data, _) => 'Created: $data',
  ///   orElse: () => 'Submit',
  /// );
  /// ```
  R maybeWhen<R>({
    required R Function() orElse,
    R Function()? onIdle,
    R Function(TVariables variables)? onPending,
    R Function(TData data, TVariables variables)? onSuccess,
    R Function(
      Object error,
      StackTrace? stackTrace,
      TVariables variables,
    )? onError,
  }) {
    return switch (this) {
      MutationIdle() => onIdle?.call() ?? orElse(),
      MutationPending(:final variables) =>
        onPending?.call(variables) ?? orElse(),
      MutationSuccess(:final data, :final variables) =>
        onSuccess?.call(data, variables) ?? orElse(),
      MutationFailure(:final error, :final stackTrace, :final variables) =>
        onError?.call(error, stackTrace, variables) ?? orElse(),
    };
  }
}

/// Idle state — no mutation has been run yet (or after [MutationController.reset]).
@immutable
final class MutationIdle<TData, TVariables>
    extends MutationState<TData, TVariables> {
  const MutationIdle();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MutationIdle<TData, TVariables>;

  @override
  int get hashCode => Object.hash(MutationIdle, TData, TVariables);

  @override
  String toString() => 'MutationIdle<$TData, $TVariables>()';
}

/// Pending state — mutation is actively running.
@immutable
final class MutationPending<TData, TVariables>
    extends MutationState<TData, TVariables> {
  /// The variables passed to [MutationController.mutate].
  final TVariables variables;

  const MutationPending({required this.variables});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationPending<TData, TVariables> &&
          variables == other.variables;

  @override
  int get hashCode =>
      Object.hash(MutationPending, TData, TVariables, variables);

  @override
  String toString() =>
      'MutationPending<$TData, $TVariables>(variables: $variables)';
}

/// Success state — mutation completed successfully.
@immutable
final class MutationSuccess<TData, TVariables>
    extends MutationState<TData, TVariables> {
  /// The data returned by the mutator.
  final TData data;

  /// The variables used in this mutation call.
  final TVariables variables;

  const MutationSuccess({
    required this.data,
    required this.variables,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationSuccess<TData, TVariables> &&
          data == other.data &&
          variables == other.variables;

  @override
  int get hashCode =>
      Object.hash(MutationSuccess, TData, TVariables, data, variables);

  @override
  String toString() =>
      'MutationSuccess<$TData, $TVariables>(data: $data, variables: $variables)';
}

/// Failure state — mutation failed.
@immutable
final class MutationFailure<TData, TVariables>
    extends MutationState<TData, TVariables> {
  /// The error that occurred.
  final Object error;

  /// Optional stack trace for debugging.
  final StackTrace? stackTrace;

  /// The variables used in this mutation call.
  final TVariables variables;

  const MutationFailure({
    required this.error,
    required this.variables,
    this.stackTrace,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationFailure<TData, TVariables> &&
          error == other.error &&
          stackTrace == other.stackTrace &&
          variables == other.variables;

  @override
  int get hashCode => Object.hash(
        MutationFailure,
        TData,
        TVariables,
        error,
        stackTrace,
        variables,
      );

  @override
  String toString() =>
      'MutationFailure<$TData, $TVariables>(error: $error, variables: $variables)';
}
