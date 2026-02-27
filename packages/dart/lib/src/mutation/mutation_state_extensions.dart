import 'mutation_state.dart';

/// Additional utility extensions on [MutationState].
extension MutationStateExtensions<TData, TVariables>
    on MutationState<TData, TVariables> {
  /// Exhaustive fold — maps every state to a value of type [R].
  ///
  /// All branches are required.
  ///
  /// ```dart
  /// final label = state.fold(
  ///   onIdle:    ()          => 'Submit',
  ///   onPending: (vars)      => 'Saving…',
  ///   onSuccess: (data, _)   => 'Saved!',
  ///   onError:   (err, _, _) => 'Retry',
  /// );
  /// ```
  R fold<R>({
    required R Function() onIdle,
    required R Function(TVariables variables) onPending,
    required R Function(TData data, TVariables variables) onSuccess,
    required R Function(
      Object error,
      StackTrace? stackTrace,
      TVariables variables,
    ) onError,
  }) {
    return switch (this) {
      MutationIdle() => onIdle(),
      MutationPending(:final variables) => onPending(variables),
      MutationSuccess(:final data, :final variables) =>
        onSuccess(data, variables),
      MutationFailure(:final error, :final stackTrace, :final variables) =>
        onError(error, stackTrace, variables),
    };
  }

  /// Converts this state to a simple [MutationStatus] enum.
  ///
  /// Useful when you only care about the coarse status and not the payload.
  MutationStatus get status => switch (this) {
        MutationIdle() => MutationStatus.idle,
        MutationPending() => MutationStatus.pending,
        MutationSuccess() => MutationStatus.success,
        MutationFailure() => MutationStatus.error,
      };
}

/// Coarse-grained status of a [MutationState].
///
/// Use [MutationState.status] to obtain the value.
enum MutationStatus {
  idle,
  pending,
  success,
  error;

  bool get isIdle => this == MutationStatus.idle;
  bool get isPending => this == MutationStatus.pending;
  bool get isSuccess => this == MutationStatus.success;
  bool get isError => this == MutationStatus.error;
}

/// Stream extensions for [MutationState].
extension MutationStateStreamExtensions<TData, TVariables>
    on Stream<MutationState<TData, TVariables>> {
  /// Filters to only [MutationSuccess] states.
  Stream<MutationSuccess<TData, TVariables>> whereSuccess() {
    return where((s) => s is MutationSuccess<TData, TVariables>)
        .cast<MutationSuccess<TData, TVariables>>();
  }

  /// Filters to only [MutationFailure] states.
  Stream<MutationFailure<TData, TVariables>> whereError() {
    return where((s) => s is MutationFailure<TData, TVariables>)
        .cast<MutationFailure<TData, TVariables>>();
  }

  /// Extracts the data from [MutationSuccess] states, emitting null otherwise.
  Stream<TData?> dataOrNull() {
    return map((s) => s.dataOrNull);
  }
}
