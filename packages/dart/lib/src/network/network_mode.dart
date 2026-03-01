/// Controls how a query or mutation behaves with respect to network status.
///
/// Mirrors the `networkMode` concept from TanStack Query v5.
enum NetworkMode {
  /// Only execute when the device is online.
  ///
  /// If the device is offline when a fetch is triggered:
  /// - The query is paused and its [FetchStatus] transitions to
  ///   [FetchStatus.paused].
  /// - The current [QoraState] transitions to
  ///   `Loading(previousData: staleData)` so the UI knows a fetch is pending.
  /// - On reconnect, paused queries are replayed automatically in batches
  ///   controlled by [ReconnectStrategy].
  ///
  /// This is the **default**. It prevents wasted requests and gives widgets
  /// enough context to display an "Awaiting connection…" indicator instead of
  /// a generic spinner.
  online,

  /// Always execute, regardless of network status.
  ///
  /// Useful for queries that read from a local cache, service worker, or any
  /// source that does not require a real network connection to succeed.
  always,

  /// Serve cached data immediately; refetch in the background when online.
  ///
  /// If offline: the cached [Success] state is preserved and the fetch is
  /// deferred until the device reconnects. If there is no cached data, the
  /// query behaves like [online] (pauses and waits).
  ///
  /// Useful for fully offline-capable apps that always prefer to return
  /// something to the UI before attempting a network refresh.
  offlineFirst,
}
