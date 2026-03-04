import 'dart:async';

import 'package:flutter/widgets.dart';
import 'qora_scope.dart';
import 'package:qora/qora.dart';

/// A widget that manages a [MutationController] and rebuilds whenever the
/// mutation state changes.
///
/// [QoraMutationBuilder] creates an internal [MutationController] on mount and
/// disposes it on unmount. The [builder] receives the current
/// [MutationState] and a [mutate] callback to trigger the mutation from the
/// UI.
///
/// When a [QoraScope] with a [ConnectivityManager] is present, the controller
/// is automatically wired to the client's network status and offline queue,
/// enabling [MutationOptions.offlineQueue] behaviour without any extra setup.
///
/// ## Basic usage
///
/// ```dart
/// QoraMutationBuilder<Post, String, void>(
///   mutator: (title) => api.createPost(title),
///   builder: (context, state, mutate) {
///     return ElevatedButton(
///       onPressed: state.isPending ? null : () => mutate('New Post'),
///       child: state.isPending
///           ? const CircularProgressIndicator()
///           : const Text('Create'),
///     );
///   },
/// )
/// ```
///
/// ## With optimistic offline queue
///
/// ```dart
/// QoraMutationBuilder<Post, String, void>(
///   mutator: (title) => api.createPost(title),
///   options: MutationOptions(
///     offlineQueue: true,
///     optimisticResponse: (title) => Post.draft(title),
///     onSuccess: (post, _, __) async => context.qora.invalidate(['posts']),
///   ),
///   builder: (context, state, mutate) {
///     return switch (state) {
///       MutationIdle() => SubmitButton(onTap: () => mutate('My Post')),
///       MutationPending() => const CircularProgressIndicator(),
///       MutationSuccess(:final data, :final isOptimistic) => ListTile(
///           title: Text(data.title),
///           // Clock icon while optimistic — not yet confirmed by server.
///           trailing: isOptimistic ? const Icon(Icons.schedule) : null,
///         ),
///       MutationFailure(:final error) => ErrorBanner(error),
///     };
///   },
/// )
/// ```
///
/// ## With optimistic updates and rollback
///
/// ```dart
/// QoraMutationBuilder<Post, String, List<Post>?>(
///   mutator: (title) => api.createPost(title),
///   options: MutationOptions(
///     onMutate: (title) async {
///       final prev = context.qora.getQueryData<List<Post>>(['posts']);
///       context.qora.setQueryData<List<Post>>(
///         ['posts'],
///         [...?prev, Post.optimistic(title)],
///       );
///       return prev; // returned as TContext for rollback
///     },
///     onError: (error, variables, prev) async {
///       context.qora.restoreQueryData(['posts'], prev);
///     },
///     onSuccess: (post, variables, _) async {
///       context.qora.invalidate(['posts']);
///     },
///   ),
///   builder: (context, state, mutate) {
///     return ElevatedButton(
///       onPressed: state.isPending ? null : () => mutate('New Post'),
///       child: const Text('Create'),
///     );
///   },
/// )
/// ```
class QoraMutationBuilder<TData, TVariables, TContext> extends StatefulWidget {
  /// The async function that performs the server-side write.
  final MutatorFunction<TData, TVariables> mutator;

  /// Lifecycle callbacks and retry configuration.
  final MutationOptions<TData, TVariables, TContext>? options;

  /// Arbitrary key-value pairs forwarded to every [MutationEvent] emitted by
  /// this controller.
  ///
  /// Use this to label mutations with domain context visible in DevTools:
  ///
  /// ```dart
  /// QoraMutationBuilder(
  ///   mutator: authApi.login,
  ///   metadata: {'category': 'auth', 'screen': 'login'},
  ///   builder: (context, state, mutate) { ... },
  /// )
  /// ```
  final Map<String, Object?>? metadata;

  /// Builds the widget tree from the current [MutationState].
  ///
  /// The [mutate] callback triggers the mutation with the given variables.
  /// It returns the result data on success, or `null` on failure / when
  /// queued offline (errors are captured in [MutationFailure] state).
  ///
  /// Pattern-match on [MutationSuccess.isOptimistic] to render a "pending
  /// sync" indicator for mutations queued while offline:
  ///
  /// ```dart
  /// MutationSuccess(:final data, :final isOptimistic) => ListTile(
  ///   title: Text(data.title),
  ///   trailing: isOptimistic ? const Icon(Icons.schedule) : null,
  /// ),
  /// ```
  final Widget Function(
    BuildContext context,
    MutationState<TData, TVariables> state,
    Future<TData?> Function(TVariables variables) mutate,
  ) builder;

  const QoraMutationBuilder({
    super.key,
    required this.mutator,
    required this.builder,
    this.options,
    this.metadata,
  });

  @override
  State<QoraMutationBuilder<TData, TVariables, TContext>> createState() =>
      _QoraMutationBuilderState<TData, TVariables, TContext>();
}

class _QoraMutationBuilderState<TData, TVariables, TContext>
    extends State<QoraMutationBuilder<TData, TVariables, TContext>> {
  late MutationController<TData, TVariables, TContext> _controller;
  StreamSubscription<MutationState<TData, TVariables>>? _subscription;
  MutationState<TData, TVariables> _state = const MutationIdle<Never, Never>() as MutationState<Never, Never>;

  @override
  void initState() {
    super.initState();
    _createController();
    _subscribe();
  }

  @override
  void didUpdateWidget(
    QoraMutationBuilder<TData, TVariables, TContext> oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    // Recreate the controller only if identity-relevant parameters changed.
    if (!identical(widget.mutator, oldWidget.mutator) ||
        !identical(widget.options, oldWidget.options) ||
        !identical(widget.metadata, oldWidget.metadata)) {
      _controller.dispose();
      _subscription?.cancel();
      _createController();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _createController() {
    final client = QoraScope.maybeOf(context);

    _controller = MutationController<TData, TVariables, TContext>(
      mutator: widget.mutator,
      options: widget.options,
      tracker: client,
      metadata: widget.metadata,
      // Wire offline support when a QoraScope with connectivity is present.
      isOnline: client != null ? () => client.isOnline : null,
      offlineQueue: client?.offlineMutationQueue,
    );
    _state = _controller.state;
  }

  void _subscribe() {
    _subscription = _controller.stream.listen(
      (state) {
        if (!mounted) return;
        setState(() => _state = state);
      },
      onError: (Object error) {
        debugPrint('[QoraMutationBuilder] Unexpected stream error: $error');
      },
    );
  }

  Future<TData?> _mutate(TVariables variables) {
    return _controller.mutate(variables);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _state, _mutate);
  }
}
