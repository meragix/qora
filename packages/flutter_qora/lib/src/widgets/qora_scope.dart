import 'package:flutter/widgets.dart';
import 'package:qora/qora.dart';

/// Widget InheritedWidget qui fournit le QoraClient à tout l'arbre de widgets
///
/// Utilisation typique :
/// ```dart
/// void main() {
///   final client = QoraClient(
///     config: QoraClientConfig(debugMode: true),
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
class QoraScope extends StatefulWidget {
  /// Le client Reqry à partager dans l'arbre de widgets
  final QoraClient client;

  /// Optionnel : un gestionnaire de cycle de vie pour gérer les refetch automatiques
  final LifecycleManager? lifecycleManager;

  /// Optionnel : un gestionnaire de connectivité pour gérer les refetch automatiques
  final ConnectivityManager? connectivityManager;

  /// L'arbre de widgets enfant
  final Widget child;

  const QoraScope({
    super.key,
    required this.client,
    this.lifecycleManager,
    this.connectivityManager,
    required this.child,
  });

  /// Récupère le QoraClient le plus proche dans l'arbre de widgets
  ///
  /// Lance une erreur si aucun QoraScope n'est trouvé
  ///
  /// Exemple :
  /// ```dart
  /// final client = QoraScope.of(context);
  /// await client.fetchQuery(...);
  /// ```
  static QoraClient of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_InheritedQoraScope>();

    if (scope == null) {
      throw FlutterError.fromParts([
        ErrorSummary('QoraScope.of() called with a context that does not contain a QoraScope.'),
        ErrorDescription(
            'No QoraClient ancestor could be found starting from the context that was passed to QoraScope.of().'),
        ErrorHint('Make sure that QoraScope is an ancestor of the widget that calls QoraScope.of().\n\n'
            'Typical usage:\n'
            'void main() {\n'
            '  runApp(\n'
            '    QoraScope(\n'
            '      client: QoraClient(),\n'
            '      child: MyApp(),\n'
            '    ),\n'
            '  );\n'
            '}'),
        context.describeElement('The context used was'),
      ]);
    }

    return scope.client;
  }

  /// Version nullable de of() qui retourne null si aucun QoraScope n'est trouvé
  ///
  /// Utile pour les cas où le QoraScope est optionnel
  static QoraClient? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_InheritedQoraScope>();
    return scope?.client;
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

/// InheritedWidget interne pour la propagation du client
class _InheritedQoraScope extends InheritedWidget {
  final QoraClient client;

  const _InheritedQoraScope({
    required this.client,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedQoraScope oldWidget) {
    // Ne notifier que si l'instance du client change
    return client != oldWidget.client;
  }
}
