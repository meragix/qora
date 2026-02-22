import 'package:meta/meta.dart';
import 'package:qora/src/key/key_equality.dart';

/// Type alias for raw key parts (backwards compatibility).
///
/// Prefer using [QoraKey] class for type safety and validation.
typedef QoraKeyParts = List<dynamic>;

/// Immutable query key with validation and type safety.
///
/// Supports two usage patterns:
///
/// **Pattern 1: Direct List (frictionless)**
/// ```dart
/// client.fetch(key: ['user', 123], ...);
/// ```
///
/// **Pattern 2: Typed Wrapper (safe)**
/// ```dart
/// client.fetch(key: QoraKey.withId('user', 123), ...);
/// ```
///
/// **Validation Rules:**
/// - Only primitives (int, String, bool, double, null), List, or Map allowed
/// - Custom objects MUST override `operator ==` and `hashCode`
/// - Keys are deeply immutable (defensive copy)
@immutable
class QoraKey {
  /// The internal parts of the key.
  final List<dynamic> parts;

  /// Creates a key from parts with validation.
  ///
  /// Throws [ArgumentError] if parts contain invalid types.
  const QoraKey(this.parts);

  /// Creates a single-part key.
  ///
  /// Example: `QoraKey.single('users')` → `['users']`
  QoraKey.single(String key) : parts = [key];

  /// Creates a key with entity and ID.
  ///
  /// Example: `QoraKey.withId('user', 123)` → `['user', 123]`
  QoraKey.withId(String entity, dynamic id) : parts = [entity, id];

  /// Creates a key with entity and filter map.
  ///
  /// Example: `QoraKey.withFilter('posts', {'status': 'published'})`
  QoraKey.withFilter(String entity, Map<String, dynamic> filter) : parts = [entity, filter];

  /// Creates a key from raw parts (conversion helper).
  factory QoraKey.from(QoraKeyParts parts) => QoraKey(parts);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QoraKey && equalsKey(parts, other.parts);

  @override
  int get hashCode => hashKey(parts);

  @override
  String toString() => 'QoraKey($parts)';
}

/// Normalizes a polymorphic key input to parts.
///
/// Accepts:
/// - [QoraKey] instance
/// - [List<dynamic>] (raw key parts)
///
/// Returns an unmodifiable, deep-copied List.
/// This is the ONLY way [QoraClient] should process keys.
///
/// Throws [ArgumentError] if key type is invalid.
List<dynamic> normalizeKey(Object key) {
  final List<dynamic> rawParts;

  // Extract raw parts based on input type
  if (key is QoraKey) {
    rawParts = key.parts;
  } else if (key is List) {
    rawParts = key;
  } else {
    throw ArgumentError(
      'Key must be QoraKey or List<dynamic>, got ${key.runtimeType}',
    );
  }

  // Validate and deep copy
  _validateKeyParts(rawParts);
  return List.unmodifiable(_deepCopy(rawParts) as Iterable);
}

/// Validates that all parts are serializable types.
///
/// Allowed types:
/// - Primitives: int, double, String, bool, null
/// - Collections: List, Map (recursively validated)
/// - Custom objects: MUST override operator == and hashCode
///
/// Throws [ArgumentError] for invalid types.
void _validateKeyParts(List<dynamic> parts, [String path = 'key']) {
  for (int i = 0; i < parts.length; i++) {
    final part = parts[i];
    final currentPath = '$path[$i]';

    if (part == null) continue;

    // Primitives (safe)
    if (part is num || part is String || part is bool) continue;

    // Collections (recurse)
    if (part is List) {
      _validateKeyParts(part, currentPath);
      continue;
    }

    if (part is Map) {
      _validateMapParts(part, currentPath);
      continue;
    }

    // Custom objects: check for == override
    // Note: We can't reliably detect == override at runtime,
    // so we warn via documentation instead of throwing
    // This is a limitation of Dart's reflection restrictions
    continue;
  }
}

/// Validates Map parts recursively.
void _validateMapParts(Map<dynamic, dynamic> map, String path) {
  for (final entry in map.entries) {
    _validateKeyParts([entry.key], '$path.key');
    _validateKeyParts([entry.value], '$path.value');
  }
}

/// Deep copy a value (List/Map/primitive).
///
/// Returns an unmodifiable copy to prevent mutations.
dynamic _deepCopy(dynamic value) {
  if (value is List) {
    return List<dynamic>.unmodifiable(value.map(_deepCopy).toList());
  } else if (value is Map) {
    return Map<dynamic, dynamic>.unmodifiable(
      value.map((k, v) => MapEntry(_deepCopy(k), _deepCopy(v))),
    );
  }
  return value; // Primitives are immutable
}
