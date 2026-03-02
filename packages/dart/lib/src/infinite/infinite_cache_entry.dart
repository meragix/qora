import 'dart:async';

import 'infinite_query_state.dart';

/// A reactive cache entry for an infinite (paginated) query.
///
/// Mirrors the design of `CacheEntry` from the regular query cache, but
/// stores [InfiniteQueryState] instead of [QoraState].
///
/// Used internally by [QoraClient] and [InfiniteQueryObserver]. Not part of
/// the public API.
class InfiniteCacheEntry<TData, TPageParam> {
  InfiniteQueryState<TData, TPageParam> _state;

  /// When this entry was first inserted into the cache.
  final DateTime createdAt;

  /// When this entry was last accessed (read or written).
  ///
  /// Updated on every [touch], [addSubscriber], [removeSubscriber], and
  /// [updateState] call. Used by [shouldEvict] for LRU-style eviction.
  DateTime lastAccessedAt;

  int _subscriberCount = 0;

  /// Garbage-collection timer, scheduled after the last subscriber
  /// unsubscribes and [QoraOptions.cacheTime] has elapsed.
  Timer? gcTimer;

  final StreamController<InfiniteQueryState<TData, TPageParam>> _controller;
  bool _isDisposed = false;

  InfiniteCacheEntry({
    required InfiniteQueryState<TData, TPageParam> state,
    DateTime? createdAt,
  })  : _state = state,
        createdAt = createdAt ?? DateTime.now(),
        lastAccessedAt = createdAt ?? DateTime.now(),
        _controller =
            StreamController<InfiniteQueryState<TData, TPageParam>>.broadcast();

  // ── State ────────────────────────────────────────────────────────────────

  /// The current query state.
  InfiniteQueryState<TData, TPageParam> get state => _state;

  /// A stream that immediately replays the current state to new subscribers,
  /// then forwards all future [updateState] calls.
  ///
  /// Multiple concurrent subscribers are supported (broadcast stream).
  Stream<InfiniteQueryState<TData, TPageParam>> get stream async* {
    if (_isDisposed) return;
    yield _state;
    yield* _controller.stream;
  }

  /// Push [newState] to all active subscribers and update internal state.
  ///
  /// No-op if this entry has been [dispose]d.
  void updateState(InfiniteQueryState<TData, TPageParam> newState) {
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

  // ── Eviction ─────────────────────────────────────────────────────────────

  /// Refresh [lastAccessedAt] to prevent premature eviction.
  void touch() => lastAccessedAt = DateTime.now();

  /// Returns `true` when the entry has been idle longer than [cacheTime]
  /// and is safe to garbage-collect.
  bool shouldEvict(Duration cacheTime) =>
      DateTime.now().difference(lastAccessedAt) > cacheTime;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Whether this entry has been disposed.
  bool get isDisposed => _isDisposed;

  /// Release all resources held by this entry.
  ///
  /// Cancels [gcTimer] and closes the internal stream controller.
  /// The entry **must not** be used after calling [dispose].
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    gcTimer?.cancel();
    _controller.close();
  }
}
