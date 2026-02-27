import 'dart:async';

import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Command gateway used by VM service handlers to control the runtime.
///
/// This abstraction prevents the DevTools extension layer from directly
/// depending on concrete runtime internals (`QoraClient`, repositories, etc.).
abstract interface class TrackingGateway {
  /// Requests a refetch for [queryKey].
  FutureOr<bool> refetch(String queryKey);

  /// Requests an invalidation for [queryKey].
  FutureOr<bool> invalidate(String queryKey);

  /// Requests a rollback of optimistic changes for [queryKey].
  ///
  /// Returns `true` when the rollback was applied.
  FutureOr<bool> rollbackOptimistic(String queryKey);

  /// Returns a full cache snapshot for DevTools inspection.
  FutureOr<CacheSnapshot> getCacheSnapshot();
}
