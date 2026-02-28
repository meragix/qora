/// Timeline event types emitted by the overlay tracker.
///
/// Each variant corresponds to a distinct action in the Qora runtime lifecycle.
/// The [displayName] getter returns a human-readable label for DevTools UI.
enum TimelineEventType {
  /// An optimistic cache write was applied before the server confirmed.
  optimisticUpdate,

  /// A mutation was dispatched to the server.
  mutationStarted,

  /// A mutation completed successfully.
  mutationSuccess,

  /// A mutation failed (network error, validation, etc.).
  mutationError,

  /// A query fetch request was initiated.
  fetchStarted,

  /// A query fetch request failed.
  fetchError,

  /// A new query key was inserted into the cache.
  queryCreated,

  /// The entire cache was cleared.
  cacheCleared;

  /// Human-readable label shown in the DevTools timeline panel.
  String get displayName => switch (this) {
        TimelineEventType.optimisticUpdate => 'Optimistic Update',
        TimelineEventType.mutationStarted => 'Mutation Started',
        TimelineEventType.mutationSuccess => 'Mutation Success',
        TimelineEventType.mutationError => 'Mutation Error',
        TimelineEventType.fetchStarted => 'Fetch Started',
        TimelineEventType.fetchError => 'Fetch Error',
        TimelineEventType.queryCreated => 'Query Created',
        TimelineEventType.cacheCleared => 'Cache Cleared',
      };
}

/// An immutable record of a single runtime event for the DevTools timeline.
///
/// The overlay tracker creates [TimelineEvent]s in response to [QoraTracker]
/// hook calls and pushes them into a bounded ring-buffer. The [TimelineNotifier]
/// consumes the stream and exposes filtered/paused views to the UI.
///
/// [key] and [mutationId] are optional — some event types (e.g. [TimelineEventType.cacheCleared])
/// are not associated with a specific key or mutation.
class TimelineEvent {
  /// The event category driving icon and colour in the timeline panel.
  final TimelineEventType type;

  /// The query or cache key associated with this event, if applicable.
  final String? key;

  /// The mutation identifier linking this event to a specific mutation lifecycle.
  final String? mutationId;

  /// Wall-clock time at which the event was recorded.
  final DateTime timestamp;

  const TimelineEvent({
    required this.type,
    this.key,
    this.mutationId,
    required this.timestamp,
  });
}
