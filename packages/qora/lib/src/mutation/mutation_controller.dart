import 'dart:async';

import 'package:qora/src/mutation/mutation_options.dart';
import 'package:qora/src/mutation/mutation_state.dart';
import 'package:qora/src/utils/query_function.dart';

/// Controls and tracks the lifecycle of a single mutation.
///
/// A [MutationController] encapsulates a [mutator] function and manages
/// the resulting state transitions:
///
/// ```
/// MutationIdle → MutationPending → MutationSuccess
///                               ↘ MutationFailure
///            ↑ reset() ──────────────────────────┘
/// ```
///
/// ## Basic usage
///
/// ```dart
/// final controller = MutationController<Post, String, void>(
///   mutator: (title) => api.createPost(title),
/// );
///
/// // Trigger the mutation
/// await controller.mutate('New Post');
///
/// // Observe state changes
/// controller.stream.listen((state) {
///   if (state is MutationSuccess<Post, String>) {
///     print('Created: ${state.data}');
///   }
/// });
///
/// // Clean up
/// controller.dispose();
/// ```
///
/// ## With optimistic updates
///
/// ```dart
/// final controller = MutationController<Post, String, List<Post>?>(
///   mutator: (title) => api.createPost(title),
///   options: MutationOptions(
///     onMutate: (title) async {
///       final prev = client.getQueryData<List<Post>>(['posts']);
///       client.setQueryData<List<Post>>(['posts'], [...?prev, Post.optimistic(title)]);
///       return prev; // snapshot saved as TContext
///     },
///     onError: (err, variables, prev) async {
///       client.restoreQueryData(['posts'], prev); // rollback
///     },
///     onSuccess: (post, variables, _) async {
///       client.invalidate(['posts']); // refetch
///     },
///   ),
/// );
/// ```
class MutationController<TData, TVariables, TContext> {
  /// The async function that performs the mutation.
  ///
  /// Named [mutator] to mirror the [fetcher] naming used in queries.
  final MutatorFunction<TData, TVariables> mutator;

  /// Lifecycle callbacks and retry configuration.
  final MutationOptions<TData, TVariables, TContext>? options;

  final StreamController<MutationState<TData, TVariables>> _controller =
      StreamController<MutationState<TData, TVariables>>.broadcast();

  MutationState<TData, TVariables> _state =
      const MutationIdle<Never, Never>() as MutationState<TData, TVariables>;

  bool _isDisposed = false;

  MutationController({
    required this.mutator,
    this.options,
  });

  /// The current state of this mutation.
  MutationState<TData, TVariables> get state => _state;

  /// A broadcast stream of state changes.
  ///
  /// Each new subscriber immediately receives the current state, then all
  /// subsequent transitions.
  Stream<MutationState<TData, TVariables>> get stream async* {
    yield _state;
    yield* _controller.stream;
  }

  /// Executes the mutation with the given [variables].
  ///
  /// State transitions:
  /// 1. Calls [MutationOptions.onMutate] (if provided) — optimistic update.
  /// 2. Transitions to [MutationPending].
  /// 3. On success → [MutationSuccess], then [MutationOptions.onSuccess],
  ///    then [MutationOptions.onSettled].
  /// 4. On failure → [MutationFailure], then [MutationOptions.onError]
  ///    (rollback), then [MutationOptions.onSettled].
  ///
  /// Returns the result data on success, or `null` on failure.
  /// Errors are captured in [MutationFailure] state and do **not** propagate
  /// to the caller — check [MutationState.errorOrNull] if needed.
  ///
  /// Throws [StateError] if the controller has been disposed.
  Future<TData?> mutate(TVariables variables) async {
    _assertNotDisposed();

    TContext? context;

    // 1. onMutate — optimistic update + snapshot
    if (options?.onMutate != null) {
      try {
        context = await options!.onMutate!(variables);
      } catch (e, st) {
        _setState(
          MutationFailure<TData, TVariables>(
            error: e,
            stackTrace: st,
            variables: variables,
          ),
        );
        return null;
      }
    }

    // 2. Transition to pending
    _setState(MutationPending<TData, TVariables>(variables: variables));

    // 3. Execute mutator (with optional retry)
    try {
      final data = await _executeWithRetry(variables);

      _setState(
        MutationSuccess<TData, TVariables>(
          data: data,
          variables: variables,
        ),
      );

      // 4a. onSuccess
      await options?.onSuccess?.call(data, variables, context);

      // 4b. onSettled (success branch)
      await options?.onSettled?.call(data, null, variables, context);

      return data;
    } catch (e, st) {
      _setState(
        MutationFailure<TData, TVariables>(
          error: e,
          stackTrace: st,
          variables: variables,
        ),
      );

      // 5. onError — rollback optimistic update
      await options?.onError?.call(e, variables, context);

      // 6. onSettled (failure branch)
      await options?.onSettled?.call(null, e, variables, context);

      return null;
    }
  }

  /// Resets the state back to [MutationIdle].
  ///
  /// Useful after displaying an error to allow the user to retry.
  void reset() {
    _assertNotDisposed();
    _setState(
      const MutationIdle<Never, Never>()
          as MutationState<TData, TVariables>,
    );
  }

  /// Disposes this controller and closes the internal stream.
  ///
  /// After [dispose], any call to [mutate] or [reset] will throw.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _controller.close();
  }

  // ── Private ──────────────────────────────────────────────────────────────

  Future<TData> _executeWithRetry(TVariables variables) async {
    final retryCount = options?.retryCount ?? 0;
    final retryDelay = options?.retryDelay ?? const Duration(seconds: 1);

    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt <= retryCount; attempt++) {
      try {
        return await mutator(variables);
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        if (attempt < retryCount) {
          // Exponential backoff: 1s, 2s, 4s, …
          final delay = retryDelay * (1 << attempt);
          await Future<void>.delayed(delay);
        }
      }
    }

    // ignore: only_throw_errors
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  void _setState(MutationState<TData, TVariables> newState) {
    if (_isDisposed) return;
    _state = newState;
    _controller.add(newState);
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('MutationController has been disposed.');
    }
  }
}
