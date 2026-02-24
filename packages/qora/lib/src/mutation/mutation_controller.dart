import 'dart:async';

import 'package:qora/src/mutation/mutation_options.dart';
import 'package:qora/src/mutation/mutation_state.dart';
import 'package:qora/src/mutation/mutation_tracker.dart';
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
/// await controller.mutate('New Post');
///
/// controller.stream.listen((state) {
///   if (state is MutationSuccess<Post, String>) {
///     print('Created: ${state.data}');
///   }
/// });
///
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
///       return prev;
///     },
///     onError: (err, variables, prev) async => client.restoreQueryData(['posts'], prev),
///     onSuccess: (post, variables, _) async => client.invalidate(['posts']),
///   ),
/// );
/// ```
///
/// ## Observability
///
/// Pass a [MutationTracker] (typically [QoraClient]) to wire this controller
/// into the global mutation event bus. [MutationBuilder] does this
/// automatically.
///
/// ```dart
/// MutationController(
///   mutator: ...,
///   tracker: client, // QoraClient implements MutationTracker
/// )
/// ```
class MutationController<TData, TVariables, TContext> {
  static int _counter = 0;

  /// Unique identifier for this controller instance.
  ///
  /// Format: `mutation_N` (monotonically increasing).
  /// Used as the key in [QoraClient.activeMutations] and [MutationEvent.mutatorId].
  final String id = 'mutation_${++_counter}';

  /// The async function that performs the mutation.
  ///
  /// Named [mutator] to mirror the [fetcher] naming used in queries.
  final MutatorFunction<TData, TVariables> mutator;

  /// Lifecycle callbacks and retry configuration.
  final MutationOptions<TData, TVariables, TContext>? options;

  /// Optional tracker (typically [QoraClient]) that receives state-change
  /// notifications for DevTools observability.
  ///
  /// When null, this controller operates in standalone mode with no global
  /// visibility. [MutationBuilder] sets this automatically via
  /// [QoraScope.maybeOf], so it is safe to use without a [QoraScope] ancestor.
  final MutationTracker? tracker;

  /// Arbitrary key-value pairs forwarded to every [MutationEvent] emitted by
  /// this controller.
  ///
  /// Use this to attach domain context that survives up to the DevTools
  /// event bus without modifying the core schema:
  ///
  /// ```dart
  /// MutationController(
  ///   mutator: authApi.login,
  ///   metadata: {'category': 'auth', 'screen': 'login'},
  /// )
  /// ```
  final Map<String, Object?>? metadata;

  final StreamController<MutationState<TData, TVariables>> _streamController =
      StreamController<MutationState<TData, TVariables>>.broadcast();

  MutationState<TData, TVariables> _state =
      const MutationIdle<Never, Never>() as MutationState<TData, TVariables>;

  bool _isDisposed = false;

  MutationController({
    required this.mutator,
    this.options,
    this.tracker,
    this.metadata,
  });

  /// The current state of this mutation.
  MutationState<TData, TVariables> get state => _state;

  /// A stream of state changes.
  ///
  /// Each new subscriber **immediately** receives the current state (synchronous
  /// capture at subscribe time), then every subsequent transition.
  ///
  /// Multiple concurrent subscriptions are supported — each gets its own
  /// single-subscription stream backed by the shared broadcast controller.
  ///
  /// ### Why not `async*`?
  ///
  /// An `async*` generator starts executing in the *next microtask*, not
  /// synchronously on `listen()`. If [mutate] is called before the first
  /// microtask fires, `_streamController.add(Pending)` runs before
  /// `yield* _streamController.stream` has subscribed, causing the event to be
  /// lost on the broadcast stream. The `StreamController.onListen` callback
  /// runs synchronously inside `listen()`, closing that window.
  Stream<MutationState<TData, TVariables>> get stream {
    StreamSubscription<MutationState<TData, TVariables>>? forwardSub;
    // `late` is required: sc is referenced inside its own onListen callback.
    late final StreamController<MutationState<TData, TVariables>> sc;
    sc = StreamController<MutationState<TData, TVariables>>(
      onListen: () {
        // Capture and emit current state synchronously at subscribe time.
        sc.add(_state);
        // Forward all future broadcast events — subscription set up before
        // listen() returns, so no events can slip through the gap.
        forwardSub = _streamController.stream.listen(
          sc.add,
          onError: sc.addError,
          onDone: sc.close,
        );
      },
      onCancel: () => forwardSub?.cancel(),
    );
    return sc.stream;
  }

  /// Executes the mutation with the given [variables].
  ///
  /// State transitions:
  /// 1. Calls [MutationOptions.onMutate] — optimistic update + snapshot.
  /// 2. Transitions to [MutationPending].
  /// 3. On success → [MutationSuccess], [MutationOptions.onSuccess],
  ///    [MutationOptions.onSettled].
  /// 4. On failure → [MutationFailure], [MutationOptions.onError] (rollback),
  ///    [MutationOptions.onSettled].
  ///
  /// Returns the result data on success, or `null` on failure.
  /// Errors are captured in [MutationFailure] state and do **not** propagate
  /// to the caller.
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
  /// Also removes this controller from the tracker's active snapshot.
  /// Useful after displaying an error to allow the user to retry.
  void reset() {
    _assertNotDisposed();
    _setState(
      const MutationIdle<Never, Never>() as MutationState<TData, TVariables>,
    );
  }

  /// Disposes this controller and closes the internal stream.
  ///
  /// Silently removes the controller from the tracker's snapshot without
  /// emitting a final event.
  ///
  /// After [dispose], any call to [mutate] or [reset] will throw.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    tracker?.untrackMutation(id);
    _streamController.close();
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
          final delay = retryDelay * (1 << attempt); // exponential backoff
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
    _streamController.add(newState);
    tracker?.trackMutation(id, newState, metadata: metadata);
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('MutationController has been disposed.');
    }
  }
}
