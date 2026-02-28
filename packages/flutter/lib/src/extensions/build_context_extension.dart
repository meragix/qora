import 'package:flutter/widgets.dart';
import 'package:qora/qora.dart';
import '../widgets/qora_scope.dart';

/// Convenience extension on [BuildContext] for accessing [QoraClient].
///
/// Prefer `context.qora` over `QoraScope.of(context)` for brevity.
///
/// ```dart
/// // Invalidate a specific query after a mutation
/// context.qora.invalidate(['posts', postId]);
///
/// // Invalidate all queries matching a predicate
/// context.qora.invalidateWhere((key) => key.firstOrNull == 'users');
///
/// // Optimistic update
/// final snapshot = context.qora.getQueryData<User>(['user', userId]);
/// context.qora.setQueryData(['user', userId], updatedUser);
/// try {
///   await api.updateUser(userId, payload);
/// } catch (_) {
///   context.qora.restoreQueryData(['user', userId], snapshot);
/// }
/// ```
extension QoraBuildContextExtension on BuildContext {
  /// Returns the [QoraClient] from the nearest [QoraScope].
  ///
  /// Throws a [FlutterError] if no [QoraScope] is found in the widget tree.
  QoraClient get qora => QoraScope.of(this);

  /// Returns the [QoraClient] from the nearest [QoraScope], or `null` if
  /// no [QoraScope] is found.
  QoraClient? get qoraOrNull => QoraScope.maybeOf(this);
}
