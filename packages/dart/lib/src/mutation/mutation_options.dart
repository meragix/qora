import '../network/network_mode.dart';

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
///   onSuccess: (post, variables, _) async {
///     // Invalidate to refetch fresh server data
///     client.invalidate(['posts']);
///   },
/// )
/// ```
///
/// ## Offline queue pattern
///
/// ```dart
/// MutationOptions<Post, String, void>(
///   networkMode: NetworkMode.online,
///   offlineQueue: true,
///   // Optional — show an immediate optimistic result while offline.
///   optimisticResponse: (title) => Post.draft(title),
///   onSuccess: (post, variables, _) async {
///     client.invalidate(['posts']);
///   },
/// )
/// ```
class MutationOptions<TData, TVariables, TContext> {
  /// Called immediately before the mutator function runs.
  ///
  /// Use this to apply optimistic updates before the server confirms them.
  /// The return value is stored as [TContext] and forwarded to [onError],
  /// [onSuccess], and [onSettled] — use it to hold a snapshot for rollback.
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
  final int retryCount;

  /// Base delay between retries. Defaults to 1 second.
  ///
  /// Uses exponential backoff: attempt 0 → 1 s, attempt 1 → 2 s, etc.
  final Duration retryDelay;

  /// Controls how this mutation behaves when the device is offline.
  ///
  /// - [NetworkMode.online] (default) — if offline and [offlineQueue] is
  ///   `true`, the mutation is enqueued; otherwise it fails immediately.
  /// - [NetworkMode.always] — always execute regardless of network status.
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
  ///    is called so you can roll back any cache changes.
  ///
  /// Use `MutationSuccess.isOptimistic` in your widget to render a "pending
  /// sync" visual indicator (e.g. greyed text, clock icon).
  final TData Function(TVariables variables)? optimisticResponse;

  const MutationOptions({
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.retryCount = 0,
    this.retryDelay = const Duration(seconds: 1),
    this.networkMode = NetworkMode.online,
    this.offlineQueue = false,
    this.optimisticResponse,
  });
}
