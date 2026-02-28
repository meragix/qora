import 'dart:async';

import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Command gateway used by VM service handlers to control the Qora runtime.
///
/// [TrackingGateway] is an anti-corruption layer between the DevTools extension
/// and `QoraClient`. It exposes only the **DevTools-relevant operations**
/// without leaking internal APIs (query options, client config, etc.).
///
/// ## Rationale (DIP)
///
/// Importing `QoraClient` from `qora_devtools_extension` would:
/// - force the extension to track every `QoraClient` API change,
/// - make unit-testing `ExtensionHandlers` impossible without a real client.
///
/// [TrackingGateway] is a thin facade — its implementor maps each method to
/// the appropriate `QoraClient` call.
///
/// ## Production implementation sketch
///
/// ```dart
/// class QoraTrackingGateway implements TrackingGateway {
///   QoraTrackingGateway(this._client);
///
///   final QoraClient _client;
///
///   @override
///   Future<bool> refetch(String queryKey) async {
///     _client.invalidateQuery(queryKey); // triggers background refetch
///     return true;
///   }
///
///   @override
///   Future<bool> rollbackOptimistic(String queryKey) async {
///     _client.restoreQueryData(queryKey);
///     return true;
///   }
///
///   @override
///   Future<CacheSnapshot> getCacheSnapshot() async { ... }
/// }
/// ```
///
/// ## Test double
///
/// ```dart
/// class FakeGateway implements TrackingGateway {
///   final refetchLog = <String>[];
///   @override
///   bool refetch(String key) { refetchLog.add(key); return true; }
///   // ...
/// }
/// ```
abstract interface class TrackingGateway {
  /// Requests an immediate refetch for [queryKey].
  ///
  /// Returns `true` when the request was dispatched successfully.
  FutureOr<bool> refetch(String queryKey);

  /// Marks [queryKey] stale and schedules a background refetch.
  ///
  /// Returns `true` when the invalidation was applied.
  FutureOr<bool> invalidate(String queryKey);

  /// Rolls back in-progress optimistic changes for [queryKey].
  ///
  /// Returns `true` when rolled back, `false` when no optimistic state exists
  /// for that key.
  FutureOr<bool> rollbackOptimistic(String queryKey);

  /// Returns a full [CacheSnapshot] for DevTools inspection.
  ///
  /// For large caches this can be a sizeable serialisation — consider adding
  /// server-side pagination parameters in a future minor version.
  FutureOr<CacheSnapshot> getCacheSnapshot();
}
