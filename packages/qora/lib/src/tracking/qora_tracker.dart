// todo: update later
abstract interface class QoraTracker {
  void onQueryFetched(String key, Object? data, dynamic status);
  void onQueryInvalidated(String key);
  void onMutationStarted(String id, String key, Object? variables);
  void onMutationSettled(String id, bool success, Object? result);
  void onOptimisticUpdate(String key, Object? optimisticData);
  void onCacheCleared();
  void dispose();
}
