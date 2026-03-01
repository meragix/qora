/// Controls how [QoraClient] replays paused queries when the device reconnects.
///
/// Without throttling, a large number of paused queries can all execute at
/// once on reconnect — the "thundering herd" problem. [ReconnectStrategy]
/// prevents this by limiting concurrent replays and adding optional jitter.
///
/// ## Usage
///
/// ```dart
/// final client = QoraClient(
///   config: QoraClientConfig(
///     reconnectStrategy: ReconnectStrategy(
///       maxConcurrent: 3,
///       jitter: Duration(milliseconds: 200),
///     ),
///   ),
/// );
/// ```
///
/// ## Pre-built strategies
///
/// ```dart
/// // Default — balanced (5 concurrent, 100 ms jitter)
/// const ReconnectStrategy()
///
/// // No throttling — useful for tests or simple apps
/// const ReconnectStrategy.instant()
///
/// // High-load backends — slow replay
/// const ReconnectStrategy.conservative()
/// ```
class ReconnectStrategy {
  /// Maximum number of paused queries replayed concurrently.
  ///
  /// Queries are processed in FIFO batches of this size. Default: `5`.
  final int maxConcurrent;

  /// Additional delay introduced between replay batches to spread the
  /// reconnect spike.
  ///
  /// The actual delay per batch is a random value in `[0, jitter]`, so
  /// individual batches do not all hit the server simultaneously.
  /// Set to [Duration.zero] to disable jitter. Default: 100 ms.
  final Duration jitter;

  const ReconnectStrategy({
    this.maxConcurrent = 5,
    this.jitter = const Duration(milliseconds: 100),
  });

  /// Replay all paused queries as fast as possible with no throttling.
  ///
  /// Use in integration tests or tiny apps with few queries.
  const ReconnectStrategy.instant()
      : maxConcurrent = 999,
        jitter = Duration.zero;

  /// Conservative replay — 2 concurrent queries, 500 ms jitter between
  /// batches.
  ///
  /// Suitable for apps with many long-lived queries or rate-limited backends.
  const ReconnectStrategy.conservative()
      : maxConcurrent = 2,
        jitter = const Duration(milliseconds: 500);
}
