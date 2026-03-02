import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:qora/qora.dart';

import 'qora_scope.dart';

/// Controls the pagination actions exposed to [InfiniteQueryBuilder.builder].
///
/// Provides a stable interface so the builder callback never holds a direct
/// reference to the underlying [InfiniteQueryObserver].
class InfiniteQueryController<TData, TPageParam> {
  final InfiniteQueryObserver<TData, TPageParam> _observer;

  const InfiniteQueryController._(this._observer);

  /// Fetch and append the next page.
  ///
  /// No-op when [InfiniteSuccess.hasNextPage] is `false` or a fetch is
  /// already in progress.
  Future<void> fetchNextPage() => _observer.fetchNextPage();

  /// Fetch and prepend the previous page.
  ///
  /// Only available when [InfiniteQueryOptions.getPreviousPageParam] is
  /// configured. No-op when [InfiniteSuccess.hasPreviousPage] is `false`.
  Future<void> fetchPreviousPage() => _observer.fetchPreviousPage();

  /// Refetch all currently loaded pages in sequence.
  ///
  /// Useful for pull-to-refresh patterns.
  Future<void> refetch() => _observer.refetch();
}

/// A widget that manages an infinite (paginated) query and rebuilds whenever
/// the state changes.
///
/// [InfiniteQueryBuilder] handles the full pagination lifecycle:
/// - Fetches the first page on mount (unless [enabled] is `false`).
/// - Subscribes to all state transitions and rebuilds accordingly.
/// - Exposes [InfiniteQueryController] so the builder can trigger
///   [fetchNextPage], [fetchPreviousPage], and [refetch] directly.
/// - Cancels the subscription cleanly on dispose.
///
/// ## Basic usage — forward scroll
///
/// ```dart
/// InfiniteQueryBuilder<List<Post>, int>(
///   queryKey: ['posts'],
///   fetcher: (page) => api.getPosts(page: page),
///   options: InfiniteQueryOptions(
///     initialPageParam: 1,
///     getNextPageParam: (last, all) => last.hasMore ? all.length + 1 : null,
///   ),
///   builder: (context, state, controller) => switch (state) {
///     InfiniteInitial() || InfiniteLoading() =>
///       const CircularProgressIndicator(),
///     InfiniteFailure(:final error) => ErrorWidget('$error'),
///     InfiniteSuccess(:final data, :final hasNextPage, :final isFetchingNextPage) =>
///       ListView.builder(
///         itemCount: data.flatten((p) => p).length + (hasNextPage ? 1 : 0),
///         itemBuilder: (ctx, i) {
///           final items = data.flatten((p) => p);
///           if (i == items.length) {
///             if (!isFetchingNextPage) controller.fetchNextPage();
///             return const CircularProgressIndicator();
///           }
///           return PostCard(items[i]);
///         },
///       ),
///   },
/// )
/// ```
///
/// ## Pull-to-refresh
///
/// ```dart
/// InfiniteQueryBuilder<List<Post>, int>(
///   queryKey: ['posts'],
///   fetcher: (page) => api.getPosts(page: page),
///   options: InfiniteQueryOptions(
///     initialPageParam: 1,
///     getNextPageParam: (last, all) => last.hasMore ? all.length + 1 : null,
///   ),
///   builder: (context, state, controller) {
///     final items = state is InfiniteSuccess<List<Post>, int>
///         ? state.data.flatten((p) => p)
///         : <Post>[];
///     return RefreshIndicator(
///       onRefresh: controller.refetch,
///       child: ListView(children: items.map(PostCard.new).toList()),
///     );
///   },
/// )
/// ```
class InfiniteQueryBuilder<TData, TPageParam> extends StatefulWidget {
  /// The query key — either a [QoraKey] or a plain [List].
  ///
  /// Changing this triggers disposal of the current observer and creation of
  /// a new one, fetching from the first page.
  final Object queryKey;

  /// The async function that fetches a single page given its [TPageParam].
  final InfiniteQueryFunction<TData, TPageParam> fetcher;

  /// Pagination and caching configuration.
  final InfiniteQueryOptions<TData, TPageParam> options;

  /// Builds the widget tree from the current state and a pagination controller.
  ///
  /// [controller] exposes [InfiniteQueryController.fetchNextPage],
  /// [InfiniteQueryController.fetchPreviousPage], and
  /// [InfiniteQueryController.refetch] — call them directly from scroll
  /// listeners, buttons, or [RefreshIndicator.onRefresh].
  final Widget Function(
    BuildContext context,
    InfiniteQueryState<TData, TPageParam> state,
    InfiniteQueryController<TData, TPageParam> controller,
  ) builder;

  /// Override the client provided by the nearest [QoraScope].
  final QoraClient? client;

  /// When `false`, the first-page fetch is not triggered on mount.
  ///
  /// The widget still subscribes to state changes, so it will rebuild as
  /// soon as another part of the app fetches via the same key.
  final bool enabled;

  const InfiniteQueryBuilder({
    super.key,
    required this.queryKey,
    required this.fetcher,
    required this.options,
    required this.builder,
    this.client,
    this.enabled = true,
  });

  @override
  State<InfiniteQueryBuilder<TData, TPageParam>> createState() =>
      _InfiniteQueryBuilderState<TData, TPageParam>();
}

class _InfiniteQueryBuilderState<TData, TPageParam>
    extends State<InfiniteQueryBuilder<TData, TPageParam>> {
  late QoraClient _client;
  late InfiniteQueryObserver<TData, TPageParam> _observer;
  late InfiniteQueryController<TData, TPageParam> _controller;
  StreamSubscription<InfiniteQueryState<TData, TPageParam>>? _subscription;
  InfiniteQueryState<TData, TPageParam> _state = const InfiniteInitial();

  @override
  void initState() {
    super.initState();
    _initClient();
    _createObserver();
    _subscribe();
    if (widget.enabled) unawaited(_observer.fetch());
  }

  @override
  void didUpdateWidget(InfiniteQueryBuilder<TData, TPageParam> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.client != oldWidget.client) {
      _initClient();
      _disposeObserver();
      _createObserver();
      _subscribe();
      if (widget.enabled) unawaited(_observer.fetch());
    } else if (widget.queryKey != oldWidget.queryKey) {
      _disposeObserver();
      _createObserver();
      _subscribe();
      if (widget.enabled) unawaited(_observer.fetch());
    } else if (widget.enabled && !oldWidget.enabled) {
      unawaited(_observer.fetch());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _disposeObserver();
    super.dispose();
  }

  void _initClient() {
    _client = widget.client ?? QoraScope.of(context);
  }

  void _createObserver() {
    _observer = InfiniteQueryObserver<TData, TPageParam>(
      client: _client,
      key: widget.queryKey,
      fetcher: widget.fetcher,
      options: widget.options,
    );
    _controller = InfiniteQueryController._(_observer);
  }

  void _disposeObserver() {
    _observer.dispose();
  }

  void _subscribe() {
    _subscription?.cancel();

    // Seed local state from the cache before the stream emits.
    _state = _observer.state;

    _subscription = _observer.stream.listen(
      (state) {
        if (!mounted) return;
        setState(() => _state = state);

        // When the query is invalidated externally, the state resets to
        // InfiniteInitial. Re-trigger the initial fetch so the UI never
        // stays blank waiting for a manual action.
        if (widget.enabled && state is InfiniteInitial<TData, TPageParam>) {
          unawaited(_observer.fetch());
        }
      },
      onError: (Object error) {
        debugPrint('[InfiniteQueryBuilder] Unexpected stream error: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _state, _controller);
}
