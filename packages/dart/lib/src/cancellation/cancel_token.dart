/// A cooperative cancellation signal for [QoraClient.fetchQuery],
/// [QoraClient.watchQuery], and [QoraClient.prefetch].
///
/// ## Principle of Responsibility
///
/// Qora does not know *how* to abort an in-flight HTTP socket, gRPC stream, or
/// WebSocket — that is the HTTP-client's job (Dio, `http`, `grpc`, …). The
/// [CancelToken] is therefore a **shared signal**: pass it both to Qora *and*
/// to the underlying network call so each layer can react appropriately.
///
/// ```dart
/// final cancelToken = CancelToken();
///
/// // Both Qora and Dio receive the same token.
/// client.fetchQuery<User>(
///   key: ['user', id],
///   fetcher: () => dio.get('/users/$id', cancelToken: cancelToken),
///   cancelToken: cancelToken,
/// );
///
/// // Cancel on widget dispose or navigation.
/// @override
/// void dispose() {
///   cancelToken.cancel();
///   super.dispose();
/// }
/// ```
///
/// ## Lifecycle
///
/// [CancelToken] is **one-shot**: once [cancel] is called, [isCancelled]
/// stays `true` and listeners are cleared. There is no reset.
///
/// When the token is cancelled while a request is in-flight, Qora:
/// 1. Silently discards the fetch result (no state transition to [Success]).
/// 2. Restores the entry to its pre-fetch state if possible.
/// 3. Calls [QoraTracker.onQueryCancelled] so DevTools shows the cancellation.
/// 4. Throws [QoraCancelException] to the original `await fetchQuery` caller.
class CancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  /// Whether [cancel] has been called on this token.
  bool get isCancelled => _cancelled;

  /// Mark this token as cancelled.
  ///
  /// All registered [whenCancelled] listeners are invoked synchronously in
  /// registration order, then cleared. Subsequent [cancel] calls are no-ops.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final fn in List.of(_listeners)) {
      fn();
    }
    _listeners.clear();
  }

  /// Register [callback] to be invoked when [cancel] is called.
  ///
  /// If the token is already cancelled, [callback] is invoked immediately and
  /// synchronously without being added to the listener list.
  void whenCancelled(void Function() callback) {
    if (_cancelled) {
      callback();
    } else {
      _listeners.add(callback);
    }
  }

  /// Deregister a previously added [callback].
  void removeListener(void Function() callback) {
    _listeners.remove(callback);
  }
}
