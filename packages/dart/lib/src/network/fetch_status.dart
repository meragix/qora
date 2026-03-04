/// Indicates whether a query is currently executing a network request.
///
/// This is the **second axis** of query state, alongside [QoraState].
/// Separating them avoids polluting [QoraState] with network concerns.
///
/// | [QoraState]    | [FetchStatus] | Meaning                                     |
/// |----------------|---------------|---------------------------------------------|
/// | [Loading]      | fetching      | First fetch in progress                     |
/// | [Loading]      | paused        | Offline — waiting to reconnect              |
/// | [Success]      | fetching      | Background SWR revalidation in progress     |
/// | [Success]      | idle          | Fresh or stale data, no request in-flight   |
/// | [Failure]      | idle          | Fetch failed, no retry scheduled            |
///
/// Use [FetchStatus.paused] to render an "Awaiting connection…" indicator
/// instead of a generic spinner, preserving a better offline experience.
///
/// ## In QoraBuilder
///
/// ```dart
/// QoraBuilder<User>(
///   queryKey: ['users', userId],
///   fetcher: () => api.getUser(userId),
///   builder: (context, state, fetchStatus) {
///     if (fetchStatus == FetchStatus.paused) {
///       return OfflineIndicator(staleData: state.dataOrNull);
///     }
///     return switch (state) {
///       Success(:final data) => UserCard(data),
///       Loading()            => const Spinner(),
///       _                    => const SizedBox.shrink(),
///     };
///   },
/// )
/// ```
enum FetchStatus {
  /// A network request is currently in-flight.
  fetching,

  /// No request is in-flight; the query is waiting for the device to come
  /// online before executing.
  ///
  /// Only set when [NetworkMode.online] is active and the device is currently
  /// offline. Once connectivity is restored, the status transitions to
  /// [fetching].
  paused,

  /// No request is in-flight and the query is not waiting for the network.
  idle,
}
