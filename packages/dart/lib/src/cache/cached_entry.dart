import 'dart:async';

import '../state/qora_state.dart';

/// An entry in the query cache.
///
/// Holds the current [QoraState] and manages a reactive broadcast stream so
/// that all active subscribers instantly receive every state transition —
/// whether triggered by a fetch, [QoraClient.setQueryData], or an
/// invalidation.
///
/// Each entry also tracks subscriber count and expiry timers, enabling
/// automatic garbage collection when no one is watching.
class CacheEntry<T> {
  QoraState<T> _state;

  /// When this entry was first inserted into the cache.
  final DateTime createdAt;

  /// When this entry was last accessed (read or written).
  ///
  /// Updated on every [touch], [addSubscriber], [removeSubscriber], and
  /// [updateState] call. Used by [shouldEvict] to implement LRU eviction.
  DateTime lastAccessedAt;

  int _subscriberCount = 0;

  /// Periodic refetch timer, set by [QoraClient.watchQuery] when
  /// [QoraOptions.refetchInterval] is configured.
  Timer? refetchTimer;

  /// Garbage-collection timer, scheduled after the last subscriber
  /// unsubscribes and [QoraOptions.cacheTime] has elapsed.
  Timer? gcTimer;

  final StreamController<QoraState<T>> _controller;
  bool _isDisposed = false;

  CacheEntry({required QoraState<T> state, DateTime? createdAt})
      : _state = state,
        createdAt = createdAt ?? DateTime.now(),
        lastAccessedAt = createdAt ?? DateTime.now(),
        _controller = StreamController<QoraState<T>>.broadcast();

  // ── State ────────────────────────────────────────────────────────────────

  /// The current query state.
  QoraState<T> get state => _state;

  /// A stream that immediately replays the current state to new subscribers,
  /// then forwards all future [updateState] calls.
  ///
  /// Multiple concurrent subscribers are supported (broadcast stream).
  /// This is the key property that makes [QoraClient.setQueryData] and
  /// [QoraClient.invalidate] push updates to all active [watchQuery] streams.
  Stream<QoraState<T>> get stream async* {
    if (_isDisposed) return;
    yield _state;
    yield* _controller.stream;
  }

  /// Push [newState] to all active subscribers and update internal state.
  ///
  /// No-op if this entry has been [dispose]d.
  void updateState(QoraState<T> newState) {
    if (_isDisposed) return;
    _state = newState;
    lastAccessedAt = DateTime.now();
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  // ── Subscriber tracking ──────────────────────────────────────────────────

  /// Whether this entry currently has at least one active stream subscriber.
  bool get isActive => _subscriberCount > 0;

  /// Number of active stream subscribers.
  int get subscriberCount => _subscriberCount;

  /// Increment subscriber count and refresh [lastAccessedAt].
  void addSubscriber() {
    _subscriberCount++;
    touch();
  }

  /// Decrement subscriber count.
  void removeSubscriber() {
    if (_subscriberCount > 0) _subscriberCount--;
    touch();
  }

  // ── Staleness & eviction ─────────────────────────────────────────────────

  /// Refresh [lastAccessedAt] to prevent premature eviction.
  void touch() => lastAccessedAt = DateTime.now();

  /// Returns `true` if the cached data is older than [staleTime].
  ///
  /// - Non-[Success] states are always considered stale.
  /// - If [staleTime] is `null`, data is **never** stale.
  bool isStale(Duration? staleTime) {
    if (staleTime == null) return false;
    return switch (_state) {
      Success(:final updatedAt) =>
        DateTime.now().difference(updatedAt) > staleTime,
      _ => true,
    };
  }

  /// Returns `true` when the entry has been idle (no access) longer than
  /// [cacheTime] and is safe to garbage-collect.
  bool shouldEvict(Duration cacheTime) =>
      DateTime.now().difference(lastAccessedAt) > cacheTime;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Whether this entry has been disposed.
  bool get isDisposed => _isDisposed;

  /// Release all resources held by this entry.
  ///
  /// Cancels [refetchTimer] and [gcTimer], closes the internal stream
  /// controller. The entry **must not** be used after calling [dispose].
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    refetchTimer?.cancel();
    gcTimer?.cancel();
    _controller.close();
  }
}
