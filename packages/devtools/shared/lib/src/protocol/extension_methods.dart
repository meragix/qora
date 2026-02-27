/// Canonical VM service extension names and event stream keys for Qora.
///
/// Keep all method names centralized in this file to avoid string drift
/// between the runtime bridge and the DevTools UI.
abstract final class QoraExtensionMethods {
  /// VM service extension prefix.
  static const String prefix = 'ext.qora';

  /// Extension method used by the UI to request a query refetch.
  static const String refetch = '$prefix.refetch';

  /// Extension method used by the UI to invalidate a query.
  static const String invalidate = '$prefix.invalidate';

  /// Extension method used by the UI to rollback an optimistic update.
  static const String rollbackOptimistic = '$prefix.rollbackOptimistic';

  /// Extension method used by the UI to fetch a full cache snapshot.
  static const String getCacheSnapshot = '$prefix.getCacheSnapshot';

  /// Extension method used by the UI to fetch a large payload in chunks.
  static const String getPayloadChunk = '$prefix.getPayloadChunk';

  /// Legacy alias kept for backward compatibility.
  static const String getPayload = '$prefix.getPayload';
}

/// Known extension event names emitted by the runtime bridge.
abstract final class QoraExtensionEvents {
  /// Main stream event kind used by Qora DevTools.
  static const String qoraEvent = 'qora:event';
}
