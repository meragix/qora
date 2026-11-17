import 'package:qora/src/client/qora_client.dart';
import 'package:qora/src/managers/connectivity_manager.dart';
import 'package:qora/src/network/network_mode.dart';
import 'package:qora/src/tag/query_tag.dart';

import 'mutation_controller.dart';
import 'mutation_state.dart';

/// Configuration and lifecycle callbacks for a [MutationController].
///
/// [TData] is the type returned by the mutator on success.
/// [TVariables] is the type of variables passed to the mutator.
/// [TContext] is an arbitrary snapshot type used for optimistic update rollback.
///
/// ## Optimistic update pattern
///
/// ```dart
/// MutationOptions<Post, String, List<Post>?>(
///   invalidates: [['posts']],
///   onMutate: (title) async {
///     // 1. Snapshot current data
///     final previous = client.getQueryData<List<Post>>(['posts']);
///     // 2. Apply optimistic update
///     client.setQueryData<List<Post>>(
///       ['posts'],
///       [...?previous, Post.optimistic(title)],
///     );
///     // 3. Return snapshot as context for potential rollback
///     return previous;
///   },
///   onError: (error, variables, previous) async {
///     // Rollback on failure
///     client.restoreQueryData(['posts'], previous);
///   },
/// )
/// ```
///
/// ## Offline queue pattern
///
/// ```dart
/// MutationOptions<Post, String, void>(
///   invalidates: [['posts']],
///   networkMode: NetworkMode.online,
///   offlineQueue: true,
///   // Optional: show an immediate optimistic result while offline.
///   optimisticResponse: (title) => Post.draft(title),
/// )
/// ```
class MutationOptions<TData, TVariables, TContext> {
  /// Called immediately before the mutator function runs.
  ///
  /// Use this to apply optimistic updates before the server confirms them.
  /// The return value is stored as [TContext] and forwarded to [onError],
  /// [onSuccess], and [onSettled]: use it to hold a snapshot for rollback.
  ///
  /// If this callback throws, the mutator is **not** called and the state
  /// transitions directly to [MutationFailure].
  final Future<TContext?> Function(TVariables variables)? onMutate;

  /// Called when the mutation completes successfully.
  ///
  /// [context] is the value returned by [onMutate], or null if [onMutate]
  /// was not provided.
  final Future<void> Function(
    TData data,
    TVariables variables,
    TContext? context,
  )? onSuccess;

  /// Called when the mutation fails.
  ///
  /// Use [context] (the snapshot from [onMutate]) to roll back optimistic
  /// updates:
  ///
  /// ```dart
  /// onError: (error, variables, previous) async {
  ///   client.restoreQueryData(['posts'], previous);
  /// }
  /// ```
  final Future<void> Function(
    Object error,
    TVariables variables,
    TContext? context,
  )? onError;

  /// Called after the mutation completes, regardless of success or failure.
  ///
  /// Exactly one of [data] or [error] is non-null.
  /// Runs after [onSuccess] or [onError].
  final Future<void> Function(
    TData? data,
    Object? error,
    TVariables variables,
    TContext? context,
  )? onSettled;

  /// Number of times to retry after a failure. Defaults to `0` (no retry).
  ///
  /// Unlike queries, mutations typically should **not** retry automatically
  /// because re-sending (e.g. a payment) can have unintended side effects.
  ///
  /// Not used by a registered mutation with [offlineQueue] set to `true`:
  /// the client's `MutationQueueConfig` replaces it.
  final int retryCount;

  /// Base delay between retries. Defaults to 1 second.
  ///
  /// Uses exponential backoff: attempt 0 → 1 s, attempt 1 → 2 s, etc.
  ///
  /// Not used by a registered mutation with [offlineQueue] set to `true`:
  /// the client's `MutationQueueConfig` replaces it.
  final Duration retryDelay;

  /// Predicate that determines whether a failed mutation should be retried.
  ///
  /// Receives the error and the zero-based attempt index that just failed.
  /// Return `false` to skip further retries for this error.
  ///
  /// When `null` (default), all failures up to [retryCount] are retried.
  ///
  /// Not used by a registered mutation with [offlineQueue] set to `true`:
  /// the client's `MutationQueueConfig` replaces it; use its `isPermanent`.
  final bool Function(Object error, int attemptIndex)? retryCondition;

  /// Controls how this mutation behaves when the device is offline.
  ///
  /// - [NetworkMode.online] (default): if offline and [offlineQueue] is
  ///   `true`, the mutation is enqueued; otherwise it fails immediately.
  /// - [NetworkMode.always]: always execute regardless of network status.
  ///   A registered mutation then skips the mutation queue.
  ///
  /// Requires a [ConnectivityManager] to be attached to [QoraClient] (done
  /// automatically when using [QoraScope] with [FlutterConnectivityManager]).
  final NetworkMode networkMode;

  /// When `true`, mutations triggered while offline are enqueued and replayed
  /// automatically when the device reconnects.
  ///
  /// Defaults to `false`. Set to `true` for write operations that must
  /// eventually reach the server (e.g. form submissions, likes, comments).
  ///
  /// Combine with [optimisticResponse] to give the user immediate feedback
  /// while the mutation waits for connectivity.
  ///
  /// With a `mutationKey` registered through `QoraClient.registerMutation`,
  /// every call goes through the client's `mutationQueue`, online or not:
  /// calls are sent in order per scope and retried by the queue's policy.
  /// [MutationController.mutate] then returns when the call succeeds, fails
  /// for good, or starts waiting (offline, or behind another call), and the
  /// callbacks run when the queued call settles.
  ///
  /// ```dart
  /// MutationOptions(
  ///   offlineQueue: true,
  ///   optimisticResponse: (title) => Post.draft(title),
  /// )
  /// ```
  final bool offlineQueue;

  /// Produces a local optimistic result to display immediately when the
  /// mutation is enqueued offline.
  ///
  /// When provided and the device is offline with [offlineQueue] set to
  /// `true`:
  /// 1. This function is called with the mutation variables.
  /// 2. [MutationController] transitions to
  ///    `MutationSuccess(data: optimistic, isOptimistic: true)` immediately.
  /// 3. The mutation is enqueued for replay on reconnect.
  /// 4. On successful replay, the state updates with the real server response
  ///    (`isOptimistic: false`).
  /// 5. On failure, the state transitions to [MutationFailure] and [onError]
  ///    is called so you can roll back any cache changes. A registered call
  ///    discarded from the mutation queue also lands here, with a
  ///    `MutationDiscardedException`.
  ///
  /// Use `MutationSuccess.isOptimistic` in your widget to render a "pending
  /// sync" visual indicator (e.g. greyed text, clock icon).
  final TData Function(TVariables variables)? optimisticResponse;

  /// List of query keys to automatically invalidate after a successful
  /// mutation.
  ///
  /// Each key is passed to [QoraClient.invalidate] after [onSuccess]
  /// completes, triggering a refetch of any active queries whose key matches.
  ///
  /// This replaces the common manual pattern:
  ///
  /// ```dart
  /// // Before - manual invalidation in onSuccess:
  /// onSuccess: (data, vars, _) async { client.invalidate(['posts']); }
  ///
  /// // After - automatic via options:
  /// invalidates: [['posts']],
  /// ```
  ///
  /// Works with offline queue replay as well, queries are invalidated on
  /// successful replay, not on the initial optimistic emit.
  ///
  /// Requires a [QoraClient] or an [invalidateQuery] callback to be wired
  /// via [MutationController] - [QoraMutationBuilder] and [useMutation] do
  /// this automatically when a [QoraScope] ancestor is present.
  final List<Object>? invalidates;

  /// Tags to invalidate after a successful mutation.
  ///
  /// When the mutation succeeds, every query that provides a matching tag is
  /// automatically refetched. This works alongside [invalidates] (which targets
  /// query keys directly) and is processed after it.
  ///
  /// Wildcard matching applies: invalidating `QueryTag('post')` refetches ALL
  /// queries that provide any tag of type `'post'`, regardless of id.
  ///
  /// ```dart
  /// MutationOptions(
  ///   invalidatesTags: [QueryTag('post')], // all post queries
  /// )
  /// ```
  final List<QueryTag>? invalidatesTags;

  /// Runs the mutation registered under this key instead of a call-site
  /// mutator.
  ///
  /// Register the key once at startup with `QoraClient.registerMutation`,
  /// then pass no `mutator` where the mutation is used. The registered
  /// mutator runs for every call made with this key, and receives a stable
  /// `MutationMeta.mutationId` to send as an idempotency key.
  ///
  /// Everything the write needs must be in the variables: a queued call can
  /// outlive the widget that made it. Callbacks set here ([onMutate],
  /// [onSuccess], [onError], [onSettled]) still run for calls made in this
  /// session, even after that widget is unmounted, so an [onError] rollback
  /// still reaches the cache. Do not use a `BuildContext` in them without
  /// checking that it is still mounted.
  ///
  /// When `null` (the default), the call site's mutator runs, as before.
  final String? mutationKey;

  const MutationOptions({
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.retryCount = 0,
    this.retryDelay = const Duration(seconds: 1),
    this.retryCondition,
    this.networkMode = NetworkMode.online,
    this.offlineQueue = false,
    this.optimisticResponse,
    this.invalidates,
    this.invalidatesTags,
    this.mutationKey,
  });
}
