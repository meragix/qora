class QoraException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const QoraException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'QoraException: $message';
}

/// Thrown by [QoraClient.fetchQuery] when the device is offline, the query's
/// [NetworkMode] is [NetworkMode.online], and there is no cached data to
/// return.
///
/// Widgets typically don't need to catch this directly — [QoraBuilder] exposes
/// [FetchStatus.paused] instead. Catch it only in imperative one-shot
/// [fetchQuery] call-sites where you need to handle the offline case
/// explicitly.
///
/// ```dart
/// try {
///   final user = await client.fetchQuery<User>(
///     key: ['users', userId],
///     fetcher: () => api.getUser(userId),
///   );
/// } on QoraOfflineException {
///   showSnackBar('You are offline. Retrying when connected…');
/// }
/// ```
class QoraOfflineException implements Exception {
  final String message;

  const QoraOfflineException([
    this.message = 'Query paused: device is offline.',
  ]);

  @override
  String toString() => 'QoraOfflineException: $message';
}
