/// Compares [a] and [b] using deep equality and returns [a] when they are
/// deeply equal, preserving referential identity for unchanged data.
///
/// When the values differ, returns [b] (the new value) so consumers see the
/// update. For [Map], [List], and [Set] the comparison is recursive. For all
/// other types it falls back to `==`. Custom model classes should override
/// `==` and `hashCode` for reliable structural sharing.
///
/// Pass `null` for [a] to skip the comparison and always return [b].
///
/// ## When to use
///
/// Structural sharing prevents unnecessary widget rebuilds when a fetch
/// returns data that is structurally identical to the previous response.
/// Without it, every successful fetch creates a new [Success] state with a
/// fresh data reference, even when nothing changed. Widgets that compare
/// using `identical()` or `==` cannot detect the no-op and rebuild.
///
/// ## Example
///
/// ```dart
/// final oldData = {'name': 'Alice', 'age': 30};
/// final newData = {'name': 'Alice', 'age': 30};
///
/// final shared = structuralShare(oldData, newData);
/// print(identical(shared, oldData)); // true
/// ```
T structuralShare<T>(T a, T b) {
  if (identical(a, b)) return a;
  if (_deepEqual(a, b)) return a;
  return b;
}

bool _deepEqual(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;
  if (a.runtimeType != b.runtimeType) return false;

  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEqual(a[key], b[key])) return false;
    }
    return true;
  }

  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEqual(a[i], b[i])) return false;
    }
    return true;
  }

  if (a is Set && b is Set) {
    if (a.length != b.length) return false;
    return a.intersection(b).length == a.length;
  }

  return a == b;
}
