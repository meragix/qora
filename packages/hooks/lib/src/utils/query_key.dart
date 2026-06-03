/// Internal hook utility - not part of the public API.
///
/// Wraps a query key list with structural (deep) equality so that
/// `useEffect` dependency arrays re-trigger only when the key *content*
/// changes, not merely when a new `List` instance is allocated.
///
/// Using `Object.hashAll` alone as the dependency value is unsafe because
/// two distinct keys can produce the same hash code (hash collision), causing
/// `useEffect` to skip re-subscription even though the key changed.
///
/// This wrapper fixes the issue by overriding `operator ==` with a recursive
/// deep-equality check, `hashCode` is still used by HashMap internals but
/// the equality gate prevents false negatives.
class QueryKey {
  final List<Object?> _key;
  const QueryKey(this._key);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryKey && _deepEquals(_key, other._key);

  @override
  int get hashCode => Object.hashAll(_key);

  static bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
