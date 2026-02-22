import 'dart:convert';

import 'package:qora/src/state/qora_state.dart';

/// Mixin for serializing and deserializing [QoraState].
///
/// Use this to persist query states to disk or send them over network.
///
/// Example:
/// ```dart
/// // Serialize
/// final state = Success(data: user, updatedAt: DateTime.now());
/// final json = QoraStateSerialization.toJson(
///   state,
///   (user) => user.toJson(),
/// );
/// await prefs.setString('user_state', jsonEncode(json));
///
/// // Deserialize
/// final jsonStr = prefs.getString('user_state')!;
/// final restored = QoraStateSerialization.fromJson<User>(
///   jsonDecode(jsonStr),
///   (json) => User.fromJson(json),
/// );
/// ```
class QoraStateSerialization {
  QoraStateSerialization._();

  /// Serializes a [QoraState] to JSON.
  ///
  /// [dataToJson] converts the data object to a JSON-serializable map.
  ///
  /// Returns a Map that can be encoded with [jsonEncode].
  static Map<String, dynamic> toJson<T>(
    QoraState<T> state,
    Map<String, dynamic> Function(T data) dataToJson,
  ) {
    return switch (state) {
      Initial() => {
          'type': 'initial',
        },
      Loading(:final previousData) => {
          'type': 'loading',
          if (previousData != null) 'previousData': dataToJson(previousData),
        },
      Success(:final data, :final updatedAt) => {
          'type': 'success',
          'data': dataToJson(data),
          'updatedAt': updatedAt.toIso8601String(),
        },
      Failure(:final error, :final previousData) => {
          'type': 'error',
          'error': error.toString(),
          if (previousData != null) 'previousData': dataToJson(previousData),
        },
    };
  }

  /// Deserializes a [QoraState] from JSON.
  ///
  /// [dataFromJson] converts a JSON map back to the data object.
  ///
  /// Returns a [QoraState] restored from the JSON.
  /// Returns [Initial] if JSON is invalid.
  static QoraState<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) dataFromJson,
  ) {
    try {
      final type = json['type'] as String?;

      switch (type) {
        case 'initial':
          return Initial<T>();

        case 'loading':
          final previousDataJson = json['previousData'];
          return Loading<T>(
            previousData: previousDataJson != null ? dataFromJson(previousDataJson as Map<String, dynamic>) : null,
          );

        case 'success':
          final dataJson = json['data'] as Map<String, dynamic>;
          final updatedAtStr = json['updatedAt'] as String;
          return Success<T>(
            data: dataFromJson(dataJson),
            updatedAt: DateTime.parse(updatedAtStr),
          );

        case 'faiture':
          final errorStr = json['error'] as String;
          final previousDataJson = json['previousData'];
          return Failure<T>(
            error: errorStr,
            previousData: previousDataJson != null ? dataFromJson(previousDataJson as Map<String, dynamic>) : null,
          );

        default:
          return Initial<T>();
      }
    } catch (e) {
      // If deserialization fails, return Initial
      return Initial<T>();
    }
  }

  /// Serializes a state to a compact JSON string.
  ///
  /// Convenience method that calls [toJson] and [jsonEncode].
  static String toJsonString<T>(
    QoraState<T> state,
    Map<String, dynamic> Function(T data) dataToJson,
  ) {
    return jsonEncode(toJson(state, dataToJson));
  }

  /// Deserializes a state from a JSON string.
  ///
  /// Convenience method that calls [jsonDecode] and [fromJson].
  static QoraState<T> fromJsonString<T>(
    String jsonString,
    T Function(Map<String, dynamic> json) dataFromJson,
  ) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return fromJson(json, dataFromJson);
  }
}

/// Extension for easier serialization access.
extension QoraStateSerializationX<T> on QoraState<T> {
  /// Serializes this state to JSON.
  ///
  /// Example:
  /// ```dart
  /// final json = state.toJson((user) => user.toJson());
  /// ```
  Map<String, dynamic> toJson(
    Map<String, dynamic> Function(T data) dataToJson,
  ) {
    return QoraStateSerialization.toJson(this, dataToJson);
  }

  /// Serializes this state to a JSON string.
  ///
  /// Example:
  /// ```dart
  /// final jsonString = state.toJsonString((user) => user.toJson());
  /// await prefs.setString('state', jsonString);
  /// ```
  String toJsonString(Map<String, dynamic> Function(T data) dataToJson) {
    return QoraStateSerialization.toJsonString(this, dataToJson);
  }
}

/// Codec for encoding/decoding states with a specific data type.
///
/// Create once and reuse for multiple serialization operations.
///
/// Example:
/// ```dart
/// final codec = QoraStateCodec<User>(
///   encode: (user) => user.toJson(),
///   decode: (json) => User.fromJson(json),
/// );
///
/// // Encode
/// final json = codec.encode(state);
///
/// // Decode
/// final state = codec.decode(json);
/// ```
class QoraStateCodec<T> {
  final Map<String, dynamic> Function(T data) encode;
  final T Function(Map<String, dynamic> json) decode;

  const QoraStateCodec({
    required this.encode,
    required this.decode,
  });

  /// Encodes a state to JSON.
  Map<String, dynamic> encodeState(QoraState<T> state) {
    return QoraStateSerialization.toJson(state, encode);
  }

  /// Decodes a state from JSON.
  QoraState<T> decodeState(Map<String, dynamic> json) {
    return QoraStateSerialization.fromJson(json, decode);
  }

  /// Encodes a state to JSON string.
  String encodeStateString(QoraState<T> state) {
    return QoraStateSerialization.toJsonString(state, encode);
  }

  /// Decodes a state from JSON string.
  QoraState<T> decodeStateString(String jsonString) {
    return QoraStateSerialization.fromJsonString(jsonString, decode);
  }
}

/// Persistence adapter for storing states.
///
/// Implement this interface to support different storage backends.
abstract class QoraStatePersistence<T> {
  /// Saves a state with the given key.
  Future<void> save(String key, QoraState<T> state);

  /// Loads a state with the given key.
  ///
  /// Returns null if key doesn't exist.
  Future<QoraState<T>?> load(String key);

  /// Deletes a state with the given key.
  Future<void> delete(String key);

  /// Clears all stored states.
  Future<void> clear();
}

/// In-memory persistence (for testing).
class InMemoryPersistence<T> implements QoraStatePersistence<T> {
  final Map<String, QoraState<T>> _storage = {};

  @override
  Future<void> save(String key, QoraState<T> state) async {
    _storage[key] = state;
  }

  @override
  Future<QoraState<T>?> load(String key) async {
    return _storage[key];
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }
}

/// SharedPreferences persistence adapter.
///
/// Example:
/// ```dart
/// final codec = QoraStateCodec<User>(
///   encode: (user) => user.toJson(),
///   decode: (json) => User.fromJson(json),
/// );
///
/// final persistence = SharedPreferencesPersistence<User>(
///   prefs: await SharedPreferences.getInstance(),
///   codec: codec,
/// );
///
/// // Save
/// await persistence.save('current_user', userState);
///
/// // Load
/// final state = await persistence.load('current_user');
/// ```
class SharedPreferencesPersistence<T> implements QoraStatePersistence<T> {
  final dynamic prefs; // SharedPreferences (avoid dependency here)
  final QoraStateCodec<T> codec;
  final String prefix;

  SharedPreferencesPersistence({
    required this.prefs,
    required this.codec,
    this.prefix = 'qora_state_',
  });

  String _getKey(String key) => '$prefix$key';

  @override
  Future<void> save(String key, QoraState<T> state) async {
    final json = codec.encodeStateString(state);
    await prefs.setString(_getKey(key), json);
  }

  @override
  Future<QoraState<T>?> load(String key) async {
    final jsonString = prefs.getString(_getKey(key)) as String?;
    if (jsonString == null) return null;

    try {
      return codec.decodeStateString(jsonString);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    await prefs.remove(_getKey(key));
  }

  @override
  Future<void> clear() async {
    final keys = prefs.getKeys() as Set<String>;
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
  }
}
