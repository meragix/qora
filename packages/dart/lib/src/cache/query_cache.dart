import 'package:qora/src/key/key_cache_map.dart';
import 'package:qora/src/key/qora_key.dart';
import 'package:qora/src/state/qora_state.dart';

import 'cached_entry.dart';

/// Internal LRU cache that stores [CacheEntry] instances keyed by normalised
/// query keys.
///
/// Features:
/// - Deep-equality key comparison via [KeyCacheMap].
/// - Optional bounded size with LRU eviction of inactive entries.
/// - [onEvict] callback for external notification (logging, storage sync).
class QueryCache {
  final KeyCacheMap<CacheEntry<dynamic>> _cache =
      KeyCacheMap<CacheEntry<dynamic>>();
  final void Function(List<dynamic> key)? _onEvict;
  final int? _maxSize;

  QueryCache({
    int? maxSize,
    void Function(List<dynamic> key)? onEvict,
  })  : _maxSize = maxSize,
        _onEvict = onEvict;

  // ── Read ─────────────────────────────────────────────────────────────────

  /// Returns the cache entry for [key], refreshing [CacheEntry.lastAccessedAt]
  /// (LRU touch). Returns `null` if not found.
  ///
  /// Throws a [StateError] when the entry exists but was originally registered
  /// under a different type parameter [T]. This indicates that two call sites
  /// are using the same query key with mismatched types — a programming error
  /// that would otherwise silently corrupt data or throw a ClassCastException
  /// deep inside a stream listener.
  ///
  /// **Example of the bug this catches:**
  /// ```dart
  /// client.fetchQuery<User>(key: ['user', 1], fetcher: fetchUser);
  /// // Later, in a different widget:
  /// client.watchState<AdminUser>(key: ['user', 1]); // ← throws StateError
  /// ```
  CacheEntry<T>? get<T>(Object key) {
    final normalized = normalizeKey(key);
    final raw = _cache.get(normalized);
    if (raw == null) return null;

    if (raw is! CacheEntry<T>) {
      throw StateError(
        'QueryCache type conflict for key $normalized:\n'
        '  Registered type : ${raw.runtimeType}\n'
        '  Requested type  : CacheEntry<$T>\n'
        'The same query key was used with two different type parameters. '
        'Use a unique key for each distinct data type, or ensure all call '
        'sites for this key use the same <T>.',
      );
    }

    raw.touch();
    return raw;
  }

  /// Returns the cache entry for [key] **without** updating
  /// [CacheEntry.lastAccessedAt].
  ///
  /// Used by the eviction sweep so that inspecting an entry does not
  /// accidentally reset its expiry clock.
  CacheEntry<dynamic>? peek(Object key) {
    final normalized = normalizeKey(key);
    return _cache.get(normalized);
  }

  /// Returns `true` if [key] has an entry in the cache.
  bool containsKey(Object key) {
    final normalized = normalizeKey(key);
    return _cache.containsKey(normalized);
  }

  // ── Write ────────────────────────────────────────────────────────────────

  /// Inserts or replaces the entry for [key].
  ///
  /// Triggers LRU eviction if [maxSize] is set and the cache is full.
  void set<T>(Object key, CacheEntry<T> entry) {
    final normalized = normalizeKey(key);
    if (_maxSize != null &&
        _cache.length >= _maxSize &&
        !_cache.containsKey(normalized)) {
      _evictLRU();
    }
    _cache.set(normalized, entry);
  }

  /// Removes and disposes the entry for [key], then calls [onEvict].
  void remove(Object key) {
    final normalized = normalizeKey(key);
    final entry = _cache.get(normalized);
    entry?.dispose();
    _cache.remove(normalized);
    _onEvict?.call(normalized);
  }

  // ── Iteration ────────────────────────────────────────────────────────────

  /// All currently cached keys (normalised).
  Iterable<List<dynamic>> get keys => _cache.keys;

  /// All cached entries as key-value pairs, without touching
  /// [CacheEntry.lastAccessedAt].
  ///
  /// Use this for bulk operations (eviction sweeps, debug snapshots) that
  /// should not affect LRU order.
  Iterable<MapEntry<List<dynamic>, CacheEntry<dynamic>>> get entries =>
      _cache.entries;

  /// Number of entries currently in the cache.
  int get length => _cache.length;

  // ── Invalidation ─────────────────────────────────────────────────────────

  /// Returns all keys for which [predicate] returns `true`.
  ///
  /// The returned iterable is eagerly evaluated so callers can safely mutate
  /// the cache while iterating the result.
  Iterable<List<dynamic>> findKeys(bool Function(List<dynamic> key) predicate) {
    return keys.where(predicate).toList();
  }

  /// Removes and disposes all entries.
  void clear() {
    for (final entry in _cache.values) {
      entry.dispose();
    }
    _cache.clear();
  }

  // ── Debugging ────────────────────────────────────────────────────────────

  /// Returns a snapshot of cache statistics for debugging.
  Map<String, dynamic> debugInfo() {
    final allEntries = _cache.values.toList();
    final activeCount = allEntries.where((e) => e.isActive).length;
    final staleCount = allEntries.where((e) => e.state is! Success).length;
    return {
      'total_queries': _cache.length,
      'active_queries': activeCount,
      'inactive_queries': _cache.length - activeCount,
      'non_success_queries': staleCount,
      'max_size': _maxSize,
      'keys': _cache.keys.toList(),
    };
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  /// Evicts the least-recently-used *inactive* entry to free space.
  ///
  /// Active entries (with subscribers) are never forcibly evicted.
  void _evictLRU() {
    if (_cache.isEmpty) return;

    List<dynamic>? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      final e = entry.value;
      if (e.isActive) continue; // Never evict active queries.
      if (oldestTime == null || e.lastAccessedAt.isBefore(oldestTime)) {
        oldestTime = e.lastAccessedAt;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      remove(oldestKey);
    }
  }
}
