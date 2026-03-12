import 'dart:async';

import 'package:flutter/widgets.dart';
import 'qora_scope.dart';
import 'package:qora/qora.dart';

/// A widget that fetches data and rebuilds whenever the query state changes.
///
/// [QoraBuilder] handles the full query lifecycle:
/// - Fetches on mount (unless [enabled] is `false`)
/// - Subscribes to all state transitions — loading, success, failure
/// - Re-fetches automatically when the query is externally invalidated
///   (e.g. after a lifecycle event or an explicit [QoraClient.invalidate] call)
/// - Cancels the subscription cleanly on dispose
///
/// The [builder] receives both the [QoraState] and a [FetchStatus] so the UI
/// can distinguish between actively fetching and waiting for network
/// (`FetchStatus.paused`).
///
/// ## Basic usage
///
/// ```dart
/// QoraBuilder<User>(
///   queryKey: ['users', userId],
///   fetcher: () => api.getUser(userId),
///   builder: (context, state, fetchStatus) {
///     if (fetchStatus == FetchStatus.paused) {
///       return OfflinePlaceholder(staleData: state.dataOrNull);
///     }
///     return switch (state) {
///       Initial()                          => const SizedBox.shrink(),
///       Loading(:final previousData)       =>
///           previousData != null
///               ? Stack(children: [UserCard(previousData), const Spinner()])
///               : const CircularProgressIndicator(),
///       Success(:final data)               => UserCard(data),
///       Failure(:final error, :final previousData) =>
///           previousData != null
///               ? Column(children: [UserCard(previousData), ErrorBanner(error)])
///               : ErrorScreen(error),
///     };
///   },
/// )
/// ```
///
/// ## Conditional (dependent) query
///
/// ```dart
/// QoraBuilder<Profile>(
///   queryKey: ['profiles', userId],
///   fetcher: () => api.getProfile(userId!),
///   enabled: userId != null,
///   builder: (context, state, fetchStatus) { ... },
/// )
/// ```
///
/// ## Preserving previous data across key changes
///
/// ```dart
/// QoraBuilder<List<Post>>(
///   queryKey: ['posts', page],
///   fetcher: () => api.getPosts(page),
///   keepPreviousData: true,
///   builder: (context, state, fetchStatus) {
///     // Loading state always carries the last page's data
///     final posts = state.dataOrNull ?? [];
///     return PostList(posts: posts, isRefreshing: state.isLoading);
///   },
/// )
/// ```
class QoraBuilder<T> extends StatefulWidget {
  /// The query key — either a [QoraKey] or a plain [List].
  ///
  /// Changing this triggers a re-subscription and a fresh fetch.
  final Object queryKey;

  /// The async function that performs the network/IO request.
  final Future<T> Function() fetcher;

  /// Builds the widget tree from the current [QoraState] and [FetchStatus].
  ///
  /// [fetchStatus] is the second axis of query state:
  /// - [FetchStatus.fetching] — a network request is in-flight.
  /// - [FetchStatus.paused] — offline, waiting for reconnect.
  /// - [FetchStatus.idle] — no request in progress.
  ///
  /// Use [FetchStatus.paused] to render an "Awaiting connection…" indicator
  /// instead of a generic spinner, keeping stale data visible to the user.
  final Widget Function(
    BuildContext context,
    QoraState<T> state,
    FetchStatus fetchStatus,
  ) builder;

  /// Per-query configuration (stale time, retry count, polling interval, …).
  ///
  /// Merged on top of [QoraClientConfig.defaultOptions].
  final QoraOptions? options;

  /// Override the client provided by the nearest [QoraScope].
  final QoraClient? client;

  /// When `false`, no fetch is triggered and the widget passively observes
  /// the current cached state.
  ///
  /// Useful for conditional queries:
  /// ```dart
  /// QoraBuilder(enabled: currentUser != null, ...)
  /// ```
  final bool enabled;

  /// When `true`, [Loading] and [Failure] states are augmented with the last
  /// successfully fetched data if the client did not already supply it.
  ///
  /// The data carried inside the state itself always takes priority. This flag
  /// only fills in the gap when [Loading.previousData] or
  /// [Failure.previousData] is `null` but the widget previously saw a
  /// [Success] state.
  ///
  /// Useful to prevent full-screen spinners on paginated lists:
  /// ```dart
  /// QoraBuilder(
  ///   keepPreviousData: true,
  ///   builder: (context, state, fetchStatus) {
  ///     final items = state.dataOrNull ?? [];
  ///     return ListView(children: items.map(ItemTile.new).toList());
  ///   },
  /// )
  /// ```
  final bool keepPreviousData;

  const QoraBuilder({
    super.key,
    required this.queryKey,
    required this.fetcher,
    required this.builder,
    this.options,
    this.client,
    this.enabled = true,
    this.keepPreviousData = false,
  });

  @override
  State<QoraBuilder<T>> createState() => _QoraBuilderState<T>();
}

class _QoraBuilderState<T> extends State<QoraBuilder<T>> {
  QoraClient? _client;
  StreamSubscription<QoraState<T>>? _stateSub;
  StreamSubscription<FetchStatus>? _fetchStatusSub;
  QoraState<T> _state = Initial<T>();
  FetchStatus _fetchStatus = FetchStatus.idle;

  /// Tracks the last successfully fetched value so that [keepPreviousData]
  /// can augment [Loading] / [Failure] states.
  T? _lastKnownData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final prev = _client;
    _initClient();
    if (_client == prev && prev != null) return;
    _subscribe();
    if (widget.enabled) unawaited(_executeFetch());
  }

  @override
  void didUpdateWidget(QoraBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.client != oldWidget.client) {
      _initClient();
      _subscribe();
      if (widget.enabled) unawaited(_executeFetch());
    } else if (widget.queryKey != oldWidget.queryKey) {
      _subscribe();
      if (widget.enabled) unawaited(_executeFetch());
    } else if (widget.enabled && !oldWidget.enabled) {
      unawaited(_executeFetch());
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _fetchStatusSub?.cancel();
    super.dispose();
  }

  void _initClient() {
    final newClient = widget.client ?? QoraScope.of(context);
    if (_client != newClient) {
      _client = newClient;
    }
  }

  void _subscribe() {
    _stateSub?.cancel();
    _fetchStatusSub?.cancel();

    final client = _client;
    if (client == null) return;

    // Subscribe to query state changes.
    _stateSub = client.watchState<T>(widget.queryKey).listen(
      (state) {
        if (!mounted) return;
        setState(() {
          _state = state;
          if (state is Success<T>) _lastKnownData = state.data;
        });

        // When the query is invalidated externally (e.g. lifecycle event or
        // an explicit client.invalidate() call), the state transitions to
        // Loading(previousData: X). We call fetchQuery here to ensure an
        // actual network request is dispatched.
        //
        // If a fetch is already in-flight or paused, the client's
        // deduplication mechanism prevents duplicate requests.
        if (widget.enabled && state is Loading<T> && state.previousData != null) {
          client
              .fetchQuery<T>(
                key: widget.queryKey,
                fetcher: widget.fetcher,
                options: widget.options,
              )
              .ignore();
        }
      },
      onError: (Object error) {
        debugPrint('[QoraBuilder] Unexpected stream error: $error');
      },
    );

    // Subscribe to fetch status (fetching / paused / idle).
    _fetchStatusSub = client.watchFetchStatus(widget.queryKey).listen(
      (status) {
        if (!mounted) return;
        setState(() => _fetchStatus = status);
      },
    );
  }

  Future<void> _executeFetch() async {
    final client = _client;
    if (client == null) return;

    try {
      await client.fetchQuery<T>(
        key: widget.queryKey,
        fetcher: widget.fetcher,
        options: widget.options,
      );
    } on QoraOfflineException {
      // Handled gracefully — FetchStatus.paused is emitted by the client and
      // received via _fetchStatusSub.
    } catch (_) {
      // Other errors are captured in the Failure state and forwarded by stream.
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveState = widget.keepPreviousData ? _withPreviousData(_state) : _state;
    return widget.builder(context, effectiveState, _fetchStatus);
  }

  /// Augments [Loading] and [Failure] states with [_lastKnownData] when the
  /// client did not already supply [previousData].
  QoraState<T> _withPreviousData(QoraState<T> state) {
    return state.maybeWhen(
      orElse: () => state,
      onInitial: () => state,
      onSuccess: (_, __) => state,
      onLoading: (previousData) {
        if (previousData != null || _lastKnownData == null) return state;
        return Loading<T>(previousData: _lastKnownData);
      },
      onError: (error, stackTrace, previousData) {
        if (previousData != null || _lastKnownData == null) return state;
        return Failure<T>(
          error: error,
          stackTrace: stackTrace,
          previousData: _lastKnownData,
        );
      },
    );
  }
}

/// A widget that observes query state **without triggering a fetch**.
///
/// Use this when another part of your widget tree (or a background service) is
/// responsible for fetching, and you just want to display the current state.
///
/// ```dart
/// // Somewhere in a parent widget:
/// // client.fetchQuery(key: ['notifications'], fetcher: api.getNotifications);
///
/// // In a badge widget:
/// QoraStateBuilder<List<Notification>>(
///   queryKey: ['notifications'],
///   builder: (context, state) {
///     final count = state.dataOrNull?.length ?? 0;
///     return Badge(count: count);
///   },
/// )
/// ```
class QoraStateBuilder<T> extends StatefulWidget {
  /// The query key — either a [QoraKey] or a plain [List].
  final Object queryKey;

  /// Builds the widget tree from the current [QoraState].
  final Widget Function(BuildContext context, QoraState<T> state) builder;

  /// Override the client provided by the nearest [QoraScope].
  final QoraClient? client;

  const QoraStateBuilder({
    super.key,
    required this.queryKey,
    required this.builder,
    this.client,
  });

  @override
  State<QoraStateBuilder<T>> createState() => _QoraStateBuilderState<T>();
}

class _QoraStateBuilderState<T> extends State<QoraStateBuilder<T>> {
  late QoraClient _client;
  StreamSubscription<QoraState<T>>? _subscription;
  QoraState<T> _state = Initial<T>();

  @override
  void initState() {
    super.initState();
    _initClient();
    _subscribe();
  }

  @override
  void didUpdateWidget(QoraStateBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.client != oldWidget.client) {
      _initClient();
      _subscribe();
    } else if (widget.queryKey != oldWidget.queryKey) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _initClient() {
    _client = widget.client ?? QoraScope.of(context);
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _client.watchState<T>(widget.queryKey).listen(
      (state) {
        if (!mounted) return;
        setState(() => _state = state);
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _state);
}
