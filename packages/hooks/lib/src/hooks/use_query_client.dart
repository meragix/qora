import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_qora/flutter_qora.dart';

/// Returns the nearest [QoraClient] from the widget tree.
///
/// Reads [QoraScope.of] via flutter_hooks' [useContext].
/// Throws a [FlutterError] if no [QoraScope] ancestor is found in the tree.
///
/// Must be called inside a [HookWidget.build] method.
///
/// ```dart
/// class MyWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final client = useQueryClient();
///     // ...
///   }
/// }
/// ```
QoraClient useQueryClient() {
  final context = useContext();
  return QoraScope.of(context);
}
