import 'package:meta/meta.dart';
import 'package:qora/src/key/key_equality.dart';
import 'package:qora/src/key/qora_key.dart';

/// A Map that uses deep equality for query key comparison.
///
/// Standard Dart Maps use reference equality for List keys, which breaks
/// query key lookups. This wrapper uses [equalsKey] and [hashKey] instead.
///
/// Supports polymorphic keys:
/// - [ReqryKey] instances
/// - [List<dynamic>] (raw parts)
///
/// **Performance**: O(n) key comparison where n = key depth.
/// Optimized for <1000 concurrent cache entries.
class KeyCacheMap<V> {
  final Map<_KeyWrapper, V> _storage = {};

  /// Get a value by key (null if not found).
  ///
  /// Accepts [ReqryKey] or [List<dynamic>].
  V? get(Object key) {
    final parts = normalizeKey(key);
    return _storage[_KeyWrapper(parts)];
  }

  /// Set a value by key.
  ///
  /// Accepts [ReqryKey] or [List<dynamic>].
  void set(Object key, V value) {
    final parts = normalizeKey(key);
    _storage[_KeyWrapper(parts)] = value;
  }

  /// Check if key exists.
  ///
  /// Accepts [ReqryKey] or [List<dynamic>].
  bool containsKey(Object key) {
    final parts = normalizeKey(key);
    return _storage.containsKey(_KeyWrapper(parts));
  }

  /// Remove a key.
  ///
  /// Accepts [ReqryKey] or [List<dynamic>].
  V? remove(Object key) {
    final parts = normalizeKey(key);
    return _storage.remove(_KeyWrapper(parts));
  }

  /// Clear all entries.
  void clear() {
    _storage.clear();
  }

  /// Get all keys as normalized parts.
  Iterable<List<dynamic>> get keys => _storage.keys.map((w) => w.key);

  /// Get all values.
  Iterable<V> get values => _storage.values;

  /// Get all ent.
  Iterable<MapEntry<List<dynamic>, V>> get entries =>
    _storage.entries.map((e) => MapEntry(e.key.key, e.value));

  /// Number of entries.
  int get length => _storage.length;

  /// Is empty?
  bool get isEmpty => _storage.isEmpty;

  /// Is not empty?
  bool get isNotEmpty => _storage.isNotEmpty;

  /// Get all entries as Map.
  Map<List<dynamic>, V> toMap() {
    return Map.fromEntries(
      _storage.entries.map((e) => MapEntry(e.key.key, e.value)),
    );
  }
}

/// Internal wrapper that provides custom equality for cache keys.
@immutable
class _KeyWrapper {
  final List<dynamic> key;
  final int _cachedHash;

  _KeyWrapper(this.key) : _cachedHash = hashKey(key);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _KeyWrapper && equalsKey(key, other.key);
  }

  @override
  int get hashCode => _cachedHash;

  @override
  String toString() => 'KeyWrapper($key)';
}
