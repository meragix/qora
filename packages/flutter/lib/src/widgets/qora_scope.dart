import 'package:flutter/widgets.dart';
import 'package:qora/qora.dart';

/// Provides a [QoraClient] to the widget tree via an [InheritedWidget].
///
/// Place [QoraScope] near the root of your app so that any descendant widget
/// can access the client via `QoraScope.of(context)` or `context.qora`.
///
/// [QoraScope] also starts and disposes the optional [lifecycleManager] and
/// [connectivityManager], and wires the connectivity manager into the client
/// via [QoraClient.attachConnectivityManager] so network-aware pausing and
/// reconnect replay work automatically.
///
/// ## Basic setup
///
/// ```dart
/// void main() {
///   final client = QoraClient(
///     config: const QoraClientConfig(debugMode: kDebugMode),
///   );
///
///   runApp(
///     QoraScope(
///       client: client,
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
///
/// ## With lifecycle and connectivity managers
///
/// ```dart
/// void main() {
///   final client = QoraClient();
///
///   runApp(
///     QoraScope(
///       client: client,
///       lifecycleManager: FlutterLifecycleManager(qoraClient: client),
///       connectivityManager: FlutterConnectivityManager(),
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
///
/// ## With offline features + network status indicator
///
/// ```dart
/// void main() {
///   final client = QoraClient(
///     config: const QoraClientConfig(
///       reconnectStrategy: ReconnectStrategy(maxConcurrent: 3),
///     ),
///   );
///
///   runApp(
///     QoraScope(
///       client: client,
///       connectivityManager: FlutterConnectivityManager(),
///       child: NetworkStatusIndicator(
///         child: MyApp(),
///       ),
///     ),
///   );
/// }
/// ```
class QoraScope extends StatefulWidget {
  /// The [QoraClient] to share across the widget tree.
  final QoraClient client;

  /// Optional lifecycle manager for refetch-on-resume behaviour.
  final LifecycleManager? lifecycleManager;

  /// Optional connectivity manager for network-aware query pausing and
  /// automatic reconnect replay.
  ///
  /// When provided, [QoraScope] calls [ConnectivityManager.start], then
  /// attaches the manager to [client] via [QoraClient.attachConnectivityManager].
  /// The manager is also exposed to descendant widgets via
  /// [QoraScope.connectivityManagerOf] so [NetworkStatusBuilder] can
  /// subscribe to status changes.
  final ConnectivityManager? connectivityManager;

  /// The subtree that can access this client.
  final Widget child;

  const QoraScope({
    super.key,
    required this.client,
    this.lifecycleManager,
    this.connectivityManager,
    required this.child,
  });

  /// Returns the [QoraClient] from the nearest [QoraScope] ancestor.
  ///
  /// Throws a [FlutterError] if no [QoraScope] is found in the widget tree.
  ///
  /// ```dart
  /// final client = QoraScope.of(context);
  /// await client.fetchQuery(...);
  /// ```
  static QoraClient of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_InheritedQoraScope>();

    if (scope == null) {
      throw FlutterError.fromParts([
        ErrorSummary(
          'QoraScope.of() called with a context that does not contain a QoraScope.',
        ),
        ErrorDescription(
          'No QoraClient ancestor could be found starting from the context '
          'that was passed to QoraScope.of().',
        ),
        ErrorHint(
          'Make sure that QoraScope is an ancestor of the widget that calls '
          'QoraScope.of().\n\n'
          'Typical usage:\n'
          'void main() {\n'
          '  runApp(\n'
          '    QoraScope(\n'
          '      client: QoraClient(),\n'
          '      child: MyApp(),\n'
          '    ),\n'
          '  );\n'
          '}',
        ),
        context.describeElement('The context used was'),
      ]);
    }

    return scope.client;
  }

  /// Returns the [QoraClient] from the nearest [QoraScope], or `null` if none
  /// is found.
  ///
  /// Useful when [QoraScope] is optional in part of the widget tree.
  static QoraClient? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InheritedQoraScope>()
        ?.client;
  }

  /// Returns the [ConnectivityManager] from the nearest [QoraScope], or
  /// `null` if none was provided.
  ///
  /// Used by [NetworkStatusBuilder] to subscribe to network status changes.
  ///
  /// ```dart
  /// final manager = QoraScope.connectivityManagerOf(context);
  /// final isOffline = manager?.currentStatus == NetworkStatus.offline;
  /// ```
  static ConnectivityManager? connectivityManagerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InheritedQoraScope>()
        ?.connectivityManager;
  }

  @override
  State<QoraScope> createState() => _QoraScopeState();
}

class _QoraScopeState extends State<QoraScope> {
  @override
  void initState() {
    super.initState();
    widget.lifecycleManager?.start();

    if (widget.connectivityManager != null) {
      // Start the manager, then attach it to the client.
      // The client reads manager.currentStatus on attach, so calling start()
      // first ensures the initial status is already resolved.
      widget.connectivityManager!.start().then((_) {
        if (mounted) {
          widget.client.attachConnectivityManager(widget.connectivityManager!);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.client.dispose();
    widget.lifecycleManager?.dispose();
    widget.connectivityManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedQoraScope(
      client: widget.client,
      connectivityManager: widget.connectivityManager,
      child: widget.child,
    );
  }
}

/// Internal [InheritedWidget] that propagates the client and connectivity
/// manager down the tree.
class _InheritedQoraScope extends InheritedWidget {
  final QoraClient client;
  final ConnectivityManager? connectivityManager;

  const _InheritedQoraScope({
    required this.client,
    required super.child,
    this.connectivityManager,
  });

  @override
  bool updateShouldNotify(_InheritedQoraScope oldWidget) {
    return client != oldWidget.client ||
        connectivityManager != oldWidget.connectivityManager;
  }
}
