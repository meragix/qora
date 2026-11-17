import 'dart:async';

import 'package:qora/src/client/qora_client.dart';
import 'package:qora/src/network/network_mode.dart';
import 'package:qora/src/network/offline_mutation_queue.dart';
import 'package:qora/src/network/pending_mutation.dart';
import 'package:qora/src/tag/query_tag.dart';
import 'package:qora/src/utils/mutation_id.dart';
import 'package:qora/src/utils/query_function.dart';

import 'mutation_meta.dart';
import 'mutation_options.dart';
import 'mutation_registry.dart';
import 'mutation_state.dart';
import 'mutation_tracker.dart';
import 'mutation_update.dart';
import 'queue/mutation_discarded_exception.dart';
import 'queue/mutation_queue.dart';

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
/// ## Offline queue
///
/// When [isOnline] returns `false` and [MutationOptions.offlineQueue] is
/// `true`, [mutate] enqueues the call instead of executing it:
///
/// ```dart
/// final controller = MutationController<Post, String, void>(
///   mutator: (title) => api.createPost(title),
///   isOnline: () => client.isOnline,
///   offlineQueue: client.offlineMutationQueue,
///   options: MutationOptions(
///     offlineQueue: true,
///     optimisticResponse: (title) => Post.draft(title),
///   ),
/// );
/// ```
///
/// ## Observability
///
/// Pass a [MutationTracker] (typically [QoraClient]) to wire this controller
/// into the global mutation event bus. [QoraMutationBuilder] does this
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
  /// Used as the key in [QoraClient.activeMutations] and [MutationUpdate.mutatorId].
  final String id = 'mutation_${++_counter}';

  /// The async function that performs the mutation.
  ///
  /// Named [mutator] to mirror the [fetcher] naming used in queries.
  ///
  /// For a registered mutation ([MutationOptions.mutationKey]), this calls
  /// the registered mutator with a fresh `mutationId`. [mutate] does not go
  /// through it: it keeps one `mutationId` across retries and replays.
  late final MutatorFunction<TData, TVariables> mutator = _callSiteMutator ??
      (variables) => _registration!.run(
            variables,
            MutationMeta(mutationId: generateMutationId(), attempt: 0),
          );

  final MutatorFunction<TData, TVariables>? _callSiteMutator;

  /// The registered mutation named by [MutationOptions.mutationKey], or
  /// `null` when the call site provides its own mutator.
  final MutationRegistration<TData, TVariables>? _registration;

  /// Lifecycle callbacks and retry configuration.
  final MutationOptions<TData, TVariables, TContext>? options;

  /// Optional tracker (typically [QoraClient]) that receives state-change
  /// notifications for DevTools observability.
  ///
  /// When null, this controller operates in standalone mode with no global
  /// visibility. [QoraMutationBuilder] sets this automatically via
  /// [QoraScope.maybeOf], so it is safe to use without a [QoraScope] ancestor.
  final MutationTracker? tracker;

  /// Arbitrary key-value pairs forwarded to every [MutationUpdate] emitted by
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

  /// Reports whether the device is currently online.
  ///
  /// Injected by [QoraMutationBuilder] from [QoraClient.isOnline]. When
  /// `null`, offline-queue logic is disabled: the mutation always executes
  /// immediately.
  final bool Function()? isOnline;

  /// The shared offline mutation queue owned by [QoraClient].
  ///
  /// When [MutationOptions.offlineQueue] is `true` and [isOnline] returns
  /// `false`, [mutate] enqueues a [PendingMutation] here instead of
  /// executing the mutator. [QoraClient] replays the queue on reconnect.
  final OfflineMutationQueue? offlineQueue;

  /// The queue of registered mutations owned by [QoraClient]
  /// (`QoraClient.mutationQueue`).
  ///
  /// A call made with [MutationOptions.mutationKey] and
  /// [MutationOptions.offlineQueue] goes through it, online or not, so calls
  /// in one scope are sent in order. Its retry policy then replaces
  /// [MutationOptions.retryCount] and [MutationOptions.retryDelay].
  final MutationQueue? mutationQueue;

  /// Callback to invalidate a single query key on successful mutation.
  ///
  /// Wired automatically by [QoraMutationBuilder] and [useMutation] from
  /// the nearest [QoraClient]. When `null`, [MutationOptions.invalidates]
  /// is a no-op.
  ///
  /// ```dart
  /// invalidateQuery: (key) => client.invalidate(key),
  /// ```
  final Future<void> Function(Object key)? invalidateQuery;

  /// Callback to invalidate queries by tag on successful mutation.
  ///
  /// Wired automatically by [QoraMutationBuilder] and [useMutation] from
  /// the nearest [QoraClient]. When `null`, [MutationOptions.invalidatesTags]
  /// is a no-op.
  ///
  /// ```dart
  /// invalidateTags: (tags) => client.invalidateTags(tags),
  /// ```
  final Future<void> Function(List<QueryTag> tags)? invalidateTags;

  final StreamController<MutationState<TData, TVariables>> _streamController =
      StreamController<MutationState<TData, TVariables>>.broadcast();

  MutationState<TData, TVariables> _state =
      const MutationIdle<Never, Never>() as MutationState<TData, TVariables>;

  bool _isDisposed = false;

  /// Creates a controller for one mutation.
  ///
  /// Pass either a [mutator], or [MutationOptions.mutationKey] together with
  /// the [registry] holding that key (`QoraClient.mutationRegistry`), not
  /// both. Throws an [ArgumentError] when both or neither are given, and a
  /// [StateError] when the key is not registered.
  MutationController({
    MutatorFunction<TData, TVariables>? mutator,
    this.options,
    this.tracker,
    this.metadata,
    this.isOnline,
    this.offlineQueue,
    this.mutationQueue,
    this.invalidateQuery,
    this.invalidateTags,
    MutationRegistry? registry,
  })  : _callSiteMutator = mutator,
        _registration = _resolveRegistration<TData, TVariables>(
          hasMutator: mutator != null,
          mutationKey: options?.mutationKey,
          registry: registry,
        );

  static MutationRegistration<TData, TVariables>?
      _resolveRegistration<TData, TVariables>({
    required bool hasMutator,
    required String? mutationKey,
    required MutationRegistry? registry,
  }) {
    if (mutationKey == null) {
      if (!hasMutator) {
        throw ArgumentError(
          'A mutator is required unless MutationOptions.mutationKey names a '
          'registered mutation.',
        );
      }
      return null;
    }
    if (hasMutator) {
      throw ArgumentError(
        'Pass either a mutator or MutationOptions.mutationKey, not both: '
        'the mutation registered under "$mutationKey" already has one.',
      );
    }
    if (registry == null) {
      throw StateError(
        'MutationOptions.mutationKey is "$mutationKey", but no mutation '
        'registry is available. Use the mutation under a QoraScope, or pass '
        'registry: client.mutationRegistry.',
      );
    }
    final registration = registry.lookup<TData, TVariables>(mutationKey);
    if (registration == null) {
      throw StateError(
        'No mutation is registered under "$mutationKey". Call '
        'client.registerMutation("$mutationKey", ...) at startup.',
      );
    }
    return registration;
  }

  /// The current state of this mutation.
  ///
  /// Includes [MutationSuccess.isOptimistic] to distinguish server-confirmed
  /// results from locally-enqueued optimistic ones.
  MutationState<TData, TVariables> get state => _state;

  /// A stream of state changes.
  ///
  /// Each new subscriber **immediately** receives the current state (synchronous
  /// capture at subscribe time), then every subsequent transition.
  ///
  /// Multiple concurrent subscriptions are supported: each gets its own
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
        // Forward all future broadcast events: subscription set up before
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
  /// ### Normal flow (online)
  ///
  /// 1. Calls [MutationOptions.onMutate]: optimistic update + snapshot.
  /// 2. Transitions to [MutationPending].
  /// 3. On success → [MutationSuccess] (`isOptimistic: false`),
  ///    [MutationOptions.onSuccess], [MutationOptions.onSettled].
  /// 4. On failure → [MutationFailure], [MutationOptions.onError] (rollback),
  ///    [MutationOptions.onSettled].
  ///
  /// ### Offline flow (when [isOnline] returns `false`)
  ///
  /// Requires [MutationOptions.offlineQueue] `true` and [offlineQueue] set:
  ///
  /// - If [MutationOptions.optimisticResponse] is provided:
  ///   transitions immediately to `MutationSuccess(isOptimistic: true)` and
  ///   enqueues for replay on reconnect.
  /// - Otherwise: transitions to [MutationPending] and enqueues for replay.
  ///   The state remains pending until the queue is replayed.
  ///
  /// ### Registered flow (with [mutationQueue])
  ///
  /// A mutation registered with `QoraClient.registerMutation`, called with
  /// [MutationOptions.offlineQueue] `true` and a [NetworkMode] other than
  /// [NetworkMode.always], always goes through [mutationQueue]. The call
  /// takes its place in the queue before `onMutate` runs, so calls keep the
  /// order of their `mutate` calls. The returned future completes when the
  /// call succeeds, fails for good, or starts waiting (offline, or behind
  /// another call). The callbacks run once, when the call settles; a later
  /// `MutationQueue.retry` runs only the registration's invalidations, and
  /// leaves this controller in [MutationFailure].
  ///
  /// Returns the result data on success, or `null` on failure / when queued.
  /// Errors are captured in [MutationFailure] state and do **not** propagate
  /// to the caller.
  ///
  /// Throws [StateError] if the controller has been disposed.
  Future<TData?> mutate(TVariables variables) async {
    _assertNotDisposed();

    final opts = options;
    final shouldQueueOffline = opts?.offlineQueue == true &&
        opts?.networkMode != NetworkMode.always &&
        isOnline != null &&
        isOnline!() == false;

    final queue = mutationQueue;
    if (_registration != null &&
        queue != null &&
        opts?.offlineQueue == true &&
        opts?.networkMode != NetworkMode.always) {
      return _enqueueRegistered(variables, opts!, queue);
    }

    // One identity per call, shared by every retry and replay of it.
    final mutationId = _registration != null ? generateMutationId() : null;

    if (shouldQueueOffline) {
      return _handleOfflineMutate(variables, opts!, mutationId: mutationId);
    }

    return _executeOnline(variables, mutationId: mutationId);
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

  /// Standard online execution path.
  ///
  /// [existingContext] is forwarded when replaying an offline-queued mutation
  /// whose [MutationOptions.onMutate] was already called at enqueue time.
  /// Passing it skips the [MutationOptions.onMutate] call on replay so the
  /// optimistic cache update is not applied twice.
  Future<TData?> _executeOnline(
    TVariables variables, {
    TContext? existingContext,
    bool skipOnMutate = false,
    String? mutationId,
  }) async {
    TContext? context = existingContext;

    // 1. onMutate: optimistic update + snapshot (skipped on offline replay)
    if (!skipOnMutate && options?.onMutate != null) {
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
      final data = await _executeWithRetry(variables, mutationId);
      await _settleSuccess(data, variables, context);
      return data;
    } catch (e, st) {
      await _settleFailure(e, st, variables, context);
      return null;
    }
  }

  /// Success state, then `onSuccess`, the invalidations (the registration's,
  /// then the call site's) and `onSettled`. Shared by direct and queued
  /// calls so both run callbacks in the same order.
  Future<void> _settleSuccess(
    TData data,
    TVariables variables,
    TContext? context,
  ) async {
    _setState(
      MutationSuccess<TData, TVariables>(
        data: data,
        variables: variables,
      ),
    );

    await options?.onSuccess?.call(data, variables, context);

    if (_registration case final registration?) {
      if (registration.invalidates case final keys?
          when invalidateQuery != null) {
        for (final key in keys) {
          await invalidateQuery!(key);
        }
      }
      if (registration.invalidatesTags case final tags?
          when invalidateTags != null) {
        await invalidateTags!(tags);
      }
    }

    if (options?.invalidates case final keys? when invalidateQuery != null) {
      for (final key in keys) {
        await invalidateQuery!(key);
      }
    }

    if (options?.invalidatesTags case final tags? when invalidateTags != null) {
      await invalidateTags!(tags);
    }

    await options?.onSettled?.call(data, null, variables, context);
  }

  /// Failure state, then `onError` (rollback) and `onSettled`.
  Future<void> _settleFailure(
    Object error,
    StackTrace stackTrace,
    TVariables variables,
    TContext? context,
  ) async {
    _setState(
      MutationFailure<TData, TVariables>(
        error: error,
        stackTrace: stackTrace,
        variables: variables,
      ),
    );
    await options?.onError?.call(error, variables, context);
    await options?.onSettled?.call(null, error, variables, context);
  }

  /// Queued path for registered mutations.
  ///
  /// Reserves the call's place in [mutationQueue], runs `onMutate`, then
  /// releases the call to the queue. Resolves when
  /// the call succeeds, fails for good, or starts waiting (offline, behind a
  /// held scope, before a retry). In the last case it resolves with the
  /// optimistic data, or `null`, and later transitions arrive through
  /// [state] while this controller is alive.
  Future<TData?> _enqueueRegistered(
    TVariables variables,
    MutationOptions<TData, TVariables, TContext> opts,
    MutationQueue queue,
  ) async {
    final completer = Completer<TData?>();
    final listener =
        _QueueListener<TData, TVariables, TContext>(this, completer);

    // Take the place in the queue before onMutate, which may await: calls
    // keep the order in which mutate was called.
    final String mutationId;
    try {
      mutationId = queue.reserve(
        key: _registration!.key,
        variables: variables,
        listener: listener,
      );
    } catch (e, st) {
      // A disposed client runs no callbacks.
      if (queue.isDisposed) return null;
      // A throwing scope: nothing was queued.
      await _settleFailure(e, st, variables, null);
      return null;
    }

    TContext? context;
    if (opts.onMutate != null) {
      try {
        context = await opts.onMutate!(variables);
      } catch (e, st) {
        queue.cancelReservation(mutationId);
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

    // Shown once the call is stored (onQueued), never for a write that
    // only exists in memory.
    final TData? optimistic =
        isOnline?.call() == false && opts.optimisticResponse != null
            ? opts.optimisticResponse!(variables)
            : null;
    _setState(MutationPending<TData, TVariables>(variables: variables));
    listener.becomeReady(variables, context, optimistic);

    try {
      final kept = await queue.release(mutationId);
      if (queue.isDisposed) return null;
      if (!kept) {
        // Discarded while onMutate ran: settle with the real context.
        await _settleFailure(
          MutationDiscardedException(
            mutationId: mutationId,
            key: _registration.key,
          ),
          StackTrace.current,
          variables,
          context,
        );
        return null;
      }
    } catch (e, st) {
      // A disposed client runs no callbacks.
      if (queue.isDisposed) return null;
      // The call could not be stored: it fails instead of looking saved.
      await _settleFailure(e, st, variables, context);
      return null;
    }
    return completer.future;
  }

  /// Offline enqueue path.
  ///
  /// Calls [MutationOptions.onMutate] immediately (so optimistic cache updates
  /// work offline), then enqueues a [PendingMutation] that replays
  /// [_executeOnline] on reconnect: skipping [onMutate] on replay to avoid
  /// applying the cache update twice.
  ///
  /// Emits an optimistic [MutationSuccess] if [MutationOptions.optimisticResponse]
  /// is provided, or [MutationPending] otherwise.
  Future<TData?> _handleOfflineMutate(
    TVariables variables,
    MutationOptions<TData, TVariables, TContext> opts, {
    String? mutationId,
  }) async {
    // 1. onMutate: run immediately so cache updates happen even while offline.
    TContext? context;
    if (opts.onMutate != null) {
      try {
        context = await opts.onMutate!(variables);
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

    // 2. Enqueue for replay when connectivity is restored.
    offlineQueue?.enqueue(
      PendingMutation(
        mutatorId: id,
        variables: variables,
        enqueuedAt: DateTime.now(),
        replay: () async {
          // Re-run the online path with the context already captured above.
          // skipOnMutate prevents the cache update from being applied twice.
          await _executeOnline(
            variables,
            existingContext: context,
            skipOnMutate: true,
            mutationId: mutationId,
          );
        },
      ),
    );

    if (opts.optimisticResponse != null) {
      // Immediately show optimistic success: data is local, not server-confirmed.
      final optimisticData = opts.optimisticResponse!(variables);
      _setState(
        MutationSuccess<TData, TVariables>(
          data: optimisticData,
          variables: variables,
          isOptimistic: true,
        ),
      );
      return Future.value(optimisticData);
    }

    // No optimistic response: stay pending until replay.
    _setState(MutationPending<TData, TVariables>(variables: variables));
    return Future.value(null);
  }

  Future<TData> _executeWithRetry(
    TVariables variables,
    String? mutationId,
  ) async {
    final retryCount = options?.retryCount ?? 0;
    final retryDelay = options?.retryDelay ?? const Duration(seconds: 1);

    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt <= retryCount; attempt++) {
      try {
        final registration = _registration;
        if (registration != null) {
          return await registration.run(
            variables,
            MutationMeta(mutationId: mutationId!, attempt: attempt),
          );
        }
        return await mutator(variables);
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        if (attempt < retryCount) {
          if (options?.retryCondition != null &&
              !options!.retryCondition!(e, attempt)) {
            break;
          }
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

/// Connects one queued call to the controller that made it.
class _QueueListener<TData, TVariables, TContext>
    implements QueuedCallListener {
  _QueueListener(this._controller, this._completer);

  final MutationController<TData, TVariables, TContext> _controller;
  final Completer<TData?> _completer;

  /// Set when onMutate finished. Before that the queue does not report to
  /// this listener, and a discard is settled by the controller itself.
  bool _ready = false;
  TVariables? _variables;
  TContext? _context;

  /// What [MutationController.mutate] returns when the call starts waiting.
  TData? _parked;

  void becomeReady(TVariables variables, TContext? context, TData? parked) {
    _variables = variables;
    _context = context;
    _parked = parked;
    _ready = true;
  }

  void _complete(TData? value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  @override
  void onQueued() {
    if (!_ready) return;
    final optimistic = _parked;
    final variables = _variables;
    if (optimistic != null && variables is TVariables) {
      _controller._setState(
        MutationSuccess<TData, TVariables>(
          data: optimistic,
          variables: variables,
          isOptimistic: true,
        ),
      );
    }
  }

  @override
  void onParked() {
    if (_ready) _complete(_parked);
  }

  @override
  Future<void> onDropped(MutationDiscardedException? reason) async {
    if (!_ready) return;
    try {
      if (reason != null) {
        await _controller._settleFailure(
          reason,
          StackTrace.current,
          _variables as TVariables,
          _context,
        );
      }
    } finally {
      _complete(null);
    }
  }

  @override
  Future<void> onSuccess(Object? data, Object? variables) async {
    try {
      final typed = data as TData;
      final vars = variables as TVariables;
      try {
        await _controller._settleSuccess(typed, vars, _context);
        _complete(typed);
      } catch (e, st) {
        // Same as a direct call: a throwing success callback fails the call.
        await _controller._settleFailure(e, st, vars, _context);
      }
    } finally {
      _complete(null);
    }
  }

  @override
  Future<void> onFailure(
    Object error,
    StackTrace stackTrace,
    Object? variables,
  ) async {
    try {
      await _controller._settleFailure(
        error,
        stackTrace,
        variables as TVariables,
        _context,
      );
    } finally {
      _complete(null);
    }
  }
}
