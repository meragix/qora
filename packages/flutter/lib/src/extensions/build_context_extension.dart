import 'package:flutter/widgets.dart';
import 'package:qora_flutter/qora_flutter.dart';

/// Convenience extension on [BuildContext] for accessing [QoraClient].
///
/// Prefer `context.qora` over `QoraScope.of(context)` for brevity.
///
/// ```dart
/// // Invalidate a specific query after a mutation
/// context.qora.invalidate(key: ['posts', postId]);
///
/// // Invalidate all queries matching a predicate
/// context.qora.invalidateWhere((key) => key.firstOrNull == 'users');
///
/// // Direct cache write (optimistic update)
/// context.mutate<Todo>(['todos', todoId], todo.copyWith(done: true));
///
/// // Optimistic update with rollback
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

  /// Pre-warms the cache for the given [key] without blocking the caller.
  ///
  /// A no-op when fresh data is already cached. Useful for imperative
  /// prefetch triggered by gesture events:
  ///
  /// ```dart
  /// GestureDetector(
  ///   onLongPress: () => context.prefetch<User>(
  ///     key: ['user', userId],
  ///     fetcher: () => api.getUser(userId),
  ///   ),
  ///   child: UserTile(userId),
  /// )
  /// ```
  Future<void> prefetch<T>({
    required Object key,
    required Future<T> Function() fetcher,
    QoraOptions? options,
  }) =>
      qora.prefetch<T>(key: key, fetcher: fetcher, options: options);

  /// Write data directly to the cache without requiring a fetcher.
  ///
  /// Shortcut for `context.qora.mutate(key, data)`. Triggers UI updates
  /// for all active subscribers watching [key].
  ///
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () => context.mutate<Todo>(['todos', id], todo.copyWith(done: true)),
  ///   child: const Text('Done'),
  /// )
  /// ```
  void mutate<T>(Object key, T data) => qora.mutate<T>(key, data);
}
