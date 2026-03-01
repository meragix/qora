/// A pair of functions that convert a value of type [T] to and from a
/// JSON-compatible representation.
///
/// The value returned by [toJson] must be accepted by `dart:convert`'s
/// [jsonEncode]: a [Map<String, dynamic>], [List], [String], [num], [bool],
/// or `null`. Nested collections are supported.
///
/// The value passed to [fromJson] is exactly what [toJson] produced after a
/// round-trip through JSON encoding and decoding.
///
/// ## Registration
///
/// Register serializers on a [PersistQoraClient] before calling [hydrate]:
///
/// ```dart
/// // Object
/// client.registerSerializer<User>(
///   QoraSerializer(
///     toJson:   (user) => user.toJson(),
///     fromJson: User.fromJson,
///   ),
/// );
///
/// // Collection
/// client.registerSerializer<List<Post>>(
///   QoraSerializer(
///     toJson:   (posts) => posts.map((p) => p.toJson()).toList(),
///     fromJson: (json)  => (json as List).map((e) => Post.fromJson(e)).toList(),
///   ),
/// );
///
/// // Primitive — no conversion needed
/// client.registerSerializer<int>(
///   QoraSerializer(toJson: (n) => n, fromJson: (json) => json as int),
/// );
/// ```
///
/// ## Obfuscation / Flutter Web
///
/// On Flutter Web or when Dart obfuscation (`--obfuscate`) is enabled,
/// [T.toString()] may be replaced by a short minified identifier (`a`, `b`,
/// …). Pass an explicit [name] to [PersistQoraClient.registerSerializer] so
/// the type discriminator stored on disk remains stable:
///
/// ```dart
/// client.registerSerializer<User>(userSerializer, name: 'User');
/// ```
///
/// The [name] must **not change across app versions** — changing it will cause
/// previously persisted entries for that type to be silently skipped on the
/// next [hydrate].
class QoraSerializer<T> {
  /// Converts a value of [T] to a JSON-encodable value.
  ///
  /// The return type is [dynamic] (not [Map<String, dynamic>]) so that
  /// primitive types, lists, and maps are all supported without wrapping.
  final dynamic Function(T value) toJson;

  /// Restores a value of [T] from the JSON value previously produced by
  /// [toJson].
  ///
  /// The argument is [dynamic] for the same reason: the stored representation
  /// may be a primitive, a [List], or a [Map].
  final T Function(dynamic json) fromJson;

  /// Creates a [QoraSerializer] with the given conversion functions.
  const QoraSerializer({
    required this.toJson,
    required this.fromJson,
  });
}
