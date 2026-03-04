import 'package:flutter/widgets.dart';
import 'package:qora/qora.dart';
import 'qora_scope.dart';

/// A widget that pre-warms the Qora cache for a query as soon as it is
/// mounted, without rendering any loading UI itself.
///
/// Wrap any widget that is *likely* to be navigated to (e.g. on hover or
/// focus) so that by the time the user arrives, data is already cached:
///
/// ```dart
/// // Pre-warm the user detail page while hovering the list tile.
/// MouseRegion(
///   onEnter: (_) => setState(() => _prefetch = true),
///   child: _prefetch
///       ? QoraPrefetch<User>(
///           queryKey: ['user', userId],
///           fetcher: () => api.getUser(userId),
///           child: UserListTile(userId: userId),
///         )
///       : UserListTile(userId: userId),
/// )
/// ```
///
/// The prefetch is a no-op when the cache already contains fresh data for
/// [queryKey]. It runs once on [initState] and is not repeated on rebuilds
/// (key changes trigger a new prefetch via [didUpdateWidget]).
///
/// See also:
/// - [QoraBuildContextExtension.prefetch] — imperative alternative.
/// - [QoraClient.prefetch] — the underlying core method.
class QoraPrefetch<T> extends StatefulWidget {
  /// The query key — either a [QoraKey] or a plain [List].
  final Object queryKey;

  /// The async function that fetches data.
  final Future<T> Function() fetcher;

  /// The child widget to render (unaffected by prefetch outcome).
  final Widget child;

  /// Per-query configuration forwarded to [QoraClient.prefetch].
  final QoraOptions? options;

  /// Override the client from the nearest [QoraScope].
  final QoraClient? client;

  const QoraPrefetch({
    super.key,
    required this.queryKey,
    required this.fetcher,
    required this.child,
    this.options,
    this.client,
  });

  @override
  State<QoraPrefetch<T>> createState() => _QoraPrefetchState<T>();
}

class _QoraPrefetchState<T> extends State<QoraPrefetch<T>> {
  late QoraClient _client;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? QoraScope.of(context);
    _trigger();
  }

  @override
  void didUpdateWidget(QoraPrefetch<T> old) {
    super.didUpdateWidget(old);
    if (widget.client != old.client) {
      _client = widget.client ?? QoraScope.of(context);
    }
    if (widget.queryKey != old.queryKey) _trigger();
  }

  void _trigger() {
    _client
        .prefetch<T>(
          key: widget.queryKey,
          fetcher: widget.fetcher,
          options: widget.options,
        )
        .ignore();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
