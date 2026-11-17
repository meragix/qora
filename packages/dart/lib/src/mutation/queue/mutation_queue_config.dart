import 'dart:math';

import 'package:meta/meta.dart';

/// How the mutation queue retries registered mutations.
///
/// Applies to calls made with `MutationOptions(mutationKey: ...,
/// offlineQueue: true)`. Their `MutationOptions.retryCount`, `retryDelay`
/// and `retryCondition` are not used: the queue's policy replaces them.
///
/// A failed attempt is either transient or permanent:
///
/// - **Transient** (the default): the call stays queued and is retried with
///   exponential backoff while the device is online. After [maxAttempts]
///   attempts it is treated as permanent. With the defaults that is 7.5 to
///   15 seconds of backoff, plus the time of the five requests.
/// - **Permanent**, when `isPermanent` returns `true` for the error: the
///   call is not retried. In a scope it becomes `blocked`; without one it
///   becomes `failed`.
///
/// The registration's `isPermanent` wins over [isPermanent] here.
///
/// ```dart
/// QoraClientConfig(
///   mutationQueue: MutationQueueConfig(
///     isPermanent: (error) => error is ApiException && error.isClientError,
///   ),
/// )
/// ```
@immutable
final class MutationQueueConfig {
  /// Attempts before a call failing with transient errors is treated as
  /// permanent. Includes the first attempt. Default: `5`.
  final int maxAttempts;

  /// Delay before the first retry. Each next retry doubles it, up to
  /// [maxDelay]. Default: 1 second.
  final Duration initialDelay;

  /// Upper bound of the delay between two attempts. Default: 30 seconds.
  final Duration maxDelay;

  /// Whether an error rejects the write for good, for registrations that
  /// define no `isPermanent` of their own. When `null` (the default), every
  /// error is transient.
  final bool Function(Object error)? isPermanent;

  /// Creates a retry policy for the mutation queue.
  const MutationQueueConfig({
    this.maxAttempts = 5,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.isPermanent,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be at least 1');

  /// The delay before the retry that follows [failedAttempts] failures.
  ///
  /// Between half of and the full exponential delay, so retries from many
  /// devices after an outage do not hit the server at the same instant.
  @internal
  Duration delayAfter(int failedAttempts, Random random) {
    final cap = maxDelay.inMicroseconds;
    var base = initialDelay.inMicroseconds;
    for (var i = 1; i < failedAttempts && base < cap; i++) {
      base *= 2;
    }
    if (base > cap) base = cap;
    final half = base ~/ 2;
    return Duration(
      microseconds: base - half + (random.nextDouble() * half).round(),
    );
  }
}
