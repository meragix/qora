import 'package:flutter/widgets.dart';
import 'package:qora/qora.dart';

/// Provides a [QoraClient] to the widget tree via an [InheritedWidget].
///
/// Place [QoraScope] near the root of your app so that any descendant widget
/// can access the client via `QoraScope.of(context)` or `context.qora`.
///
/// [QoraScope] also starts and disposes the optional [lifecycleManager] and
/// [connectivityManager], ensuring they are active for the lifetime of the
/// scope.
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
///       connectivityManager: FlutterConnectivityManager(qoraClient: client),
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
class QoraScope extends StatefulWidget {
  /// The [QoraClient] to share across the widget tree.
  final QoraClient client;

  /// Optional lifecycle manager for refetch-on-resume behaviour.
  final LifecycleManager? lifecycleManager;

  /// Optional connectivity manager for refetch-on-reconnect behaviour.
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

  @override
  State<QoraScope> createState() => _QoraScopeState();
}

class _QoraScopeState extends State<QoraScope> {
  @override
  void initState() {
    super.initState();
    widget.lifecycleManager?.start();
    widget.connectivityManager?.start();
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
      child: widget.child,
    );
  }
}

/// Internal [InheritedWidget] that propagates the client down the tree.
class _InheritedQoraScope extends InheritedWidget {
  final QoraClient client;

  const _InheritedQoraScope({
    required this.client,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedQoraScope oldWidget) {
    return client != oldWidget.client;
  }
}
