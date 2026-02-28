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
/// ## Basic usage
///
/// ```dart
/// QoraMutationBuilder<Post, String, void>(
///   mutationFn: (title) => api.createPost(title),
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
/// ## With optimistic updates and rollback
///
/// ```dart
/// QoraMutationBuilder<Post, String, List<Post>?>(
///   mutationFn: (title) => api.createPost(title),
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
///
/// ## Handling success and errors in the builder
///
/// ```dart
/// QoraMutationBuilder<Post, String, void>(
///   mutationFn: (title) => api.createPost(title),
///   builder: (context, state, mutate) {
///     return switch (state) {
///       MutationIdle()                    => SubmitButton(onTap: () => mutate('Post')),
///       MutationPending()                  => const CircularProgressIndicator(),
///       MutationSuccess(:final data)       => Text('Created: ${data.title}'),
///       MutationFailure(:final error)      => ErrorBanner(error),
///     };
///   },
/// )
/// ```
class QoraMutationBuilder<TData, TVariables, TContext> extends StatefulWidget {
  /// The async function that performs the server-side write.
  final MutatorFunction<TData, TVariables> mutationFn;

  /// Lifecycle callbacks and retry configuration.
  final MutationOptions<TData, TVariables, TContext>? options;

  /// Arbitrary key-value pairs forwarded to every [MutationEvent] emitted by
  /// this controller.
  ///
  /// Use this to label mutations with domain context visible in DevTools:
  ///
  /// ```dart
  /// QoraMutationBuilder(
  ///   mutationFn: authApi.login,
  ///   metadata: {'category': 'auth', 'screen': 'login'},
  ///   builder: (context, state, mutate) { ... },
  /// )
  /// ```
  final Map<String, Object?>? metadata;

  /// Builds the widget tree from the current [MutationState].
  ///
  /// The [mutate] callback triggers the mutation with the given variables.
  /// It returns `null` on failure (errors are captured in [MutationFailure]
  /// state).
  final Widget Function(
    BuildContext context,
    MutationState<TData, TVariables> state,
    Future<TData?> Function(TVariables variables) mutate,
  ) builder;

  const QoraMutationBuilder({
    super.key,
    required this.mutationFn,
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
  MutationState<TData, TVariables> _state =
      const MutationIdle<Never, Never>() as MutationState<Never, Never>;

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
    if (!identical(widget.mutationFn, oldWidget.mutationFn) ||
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
    _controller = MutationController<TData, TVariables, TContext>(
      mutator: widget.mutationFn,
      options: widget.options,
      tracker: QoraScope.maybeOf(context),
      metadata: widget.metadata,
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
