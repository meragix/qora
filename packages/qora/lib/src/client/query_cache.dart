import 'package:qora/src/client/cached_entry.dart';
import 'package:qora/src/key/key_cache_map.dart';
import 'package:qora/src/key/qora_key.dart';
import 'package:qora/src/state/qora_state.dart';

/// Internal LRU cache that stores [CacheEntry] instances keyed by normalised
/// query keys.
///
/// Features:
/// - Deep-equality key comparison via [KeyCacheMap].
/// - Optional bounded size with LRU eviction of inactive entries.
/// - [onEvict] callback for external notification (logging, storage sync).
class QueryCache {
  final KeyCacheMap<CacheEntry<dynamic>> _cache = KeyCacheMap<CacheEntry<dynamic>>();
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
  CacheEntry<T>? get<T>(Object key) {
    final normalized = normalizeKey(key);
    final entry = _cache.get(normalized) as CacheEntry<T>?;
    entry?.touch();
    return entry;
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
    if (_maxSize != null && _cache.length >= _maxSize && !_cache.containsKey(normalized)) {
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
  Iterable<MapEntry<List<dynamic>, CacheEntry<dynamic>>> get entries => _cache.entries;

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
