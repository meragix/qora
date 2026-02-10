/// Exception standardisée Qora
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
