/// Computes a deep hash code for a query key.
///
/// Handles:
/// - Primitives (int, String, bool, etc.)
/// - Lists (recursively)
/// - Maps (recursively, order-independent)
/// - Custom objects (via their [hashCode])
int hashKey(List<dynamic> key) {
  return _deepHash(key);
}

/// Checks deep equality between two query keys.
///
/// Returns `true` if:
/// - Both lists have the same length
/// - All elements are deeply equal (recursively)
/// - Map keys/values are equal (order-independent)
///
/// Custom objects MUST override [operator ==] and [hashCode].
bool equalsKey(List<dynamic> a, List<dynamic> b) {
  return _deepEquals(a, b);
}

// --- INTERNAL IMPLEMENTATION ---

int _deepHash(dynamic value) {
  if (value == null) return 0;

  if (value is List) {
    // Combine hashes of all elements
    return Object.hashAll(value.map(_deepHash));
  }

  if (value is Map) {
    // Order-independent hash for maps
    // We can't use hashAll directly because map order varies
    final entries = value.entries.toList()
      ..sort((a, b) {
        final keyHashA = _deepHash(a.key);
        final keyHashB = _deepHash(b.key);
        return keyHashA.compareTo(keyHashB);
      });

    return Object.hashAll(
      entries.expand((e) => [_deepHash(e.key), _deepHash(e.value)]),
    );
  }

  // Primitives and custom objects
  return value.hashCode;
}

bool _deepEquals(dynamic a, dynamic b) {
  // Identity check
  if (identical(a, b)) return true;

  // Null check
  if (a == null || b == null) return false;

  // Type mismatch
  if (a.runtimeType != b.runtimeType) return false;

  // Lists
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }

  // Maps (order-independent)
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }

  // Primitives & Custom objects (relies on operator ==)
  return a == b;
}
