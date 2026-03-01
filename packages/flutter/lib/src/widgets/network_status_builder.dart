import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:qora/qora.dart';

import 'qora_scope.dart';

/// A widget that rebuilds whenever the [NetworkStatus] changes.
///
/// Subscribes to the [ConnectivityManager] exposed by the nearest [QoraScope]
/// and calls [builder] with the latest status on every transition.
///
/// ## Basic usage
///
/// ```dart
/// NetworkStatusBuilder(
///   builder: (context, status) {
///     return status == NetworkStatus.offline
///         ? const OfflineBanner()
///         : const SizedBox.shrink();
///   },
/// )
/// ```
///
/// ## With child optimisation
///
/// When your widget subtree is expensive to rebuild, pass it as [child].
/// The framework will reuse it across [builder] calls:
///
/// ```dart
/// NetworkStatusBuilder(
///   builder: (context, status, child) {
///     return Column(
///       children: [
///         if (status == NetworkStatus.offline) const OfflineBanner(),
///         child!,
///       ],
///     );
///   },
///   child: const ExpensiveContentTree(),
/// )
/// ```
///
/// ## Requirements
///
/// A [QoraScope] with a [ConnectivityManager] must be an ancestor of this
/// widget. Without a [ConnectivityManager], the builder emits
/// [NetworkStatus.unknown] and never updates.
class NetworkStatusBuilder extends StatefulWidget {
  /// Builds the widget tree for the given [NetworkStatus].
  ///
  /// Called immediately with the current status and on every subsequent
  /// network transition.
  final Widget Function(
    BuildContext context,
    NetworkStatus status,
    Widget? child,
  ) builder;

  /// Optional child widget passed through to [builder] unchanged.
  ///
  /// Use this to avoid rebuilding expensive subtrees on status changes.
  final Widget? child;

  const NetworkStatusBuilder({
    super.key,
    required this.builder,
    this.child,
  });

  @override
  State<NetworkStatusBuilder> createState() => _NetworkStatusBuilderState();
}

class _NetworkStatusBuilderState extends State<NetworkStatusBuilder> {
  StreamSubscription<NetworkStatus>? _subscription;
  NetworkStatus _status = NetworkStatus.unknown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _subscription?.cancel();

    final manager = QoraScope.connectivityManagerOf(context);
    if (manager == null) return;

    _status = manager.currentStatus;
    _subscription = manager.statusStream.listen((status) {
      if (!mounted) return;
      setState(() => _status = status);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _status, widget.child);
  }
}
