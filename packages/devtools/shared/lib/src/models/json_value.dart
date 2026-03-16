/// Type-safe representation of any JSON value.
///
/// Used by both the in-app overlay and the IDE extension to drive their
/// respective JSON viewers without depending on `vm_service` or Flutter.
///
/// Use [JsonValue.fromDynamic] to parse any value that came out of
/// `dart:convert jsonDecode`, a `Map`, a `List`, or any Dart primitive.
sealed class JsonValue {
  const JsonValue();

  /// Converts any [raw] dynamic value into a fully-typed [JsonValue] tree.
  ///
  /// Handles: `null`, [bool], [num], [String], [List], [Map].
  /// Anything else is coerced to [JsonString] via `.toString()`.
  factory JsonValue.fromDynamic(dynamic raw) {
    if (raw == null) return const JsonNull();
    if (raw is bool) return JsonBool(raw);
    if (raw is num) return JsonNumber(raw);
    if (raw is String) return JsonString(raw);
    if (raw is List) {
      return JsonArray(raw.map(JsonValue.fromDynamic).toList());
    }
    if (raw is Map) {
      return JsonObject(
        raw.map((k, v) => MapEntry(k.toString(), JsonValue.fromDynamic(v))),
      );
    }
    return JsonString(raw.toString());
  }

  /// Whether this value has no children (cannot be expanded in a tree).
  bool get isPrimitive =>
      this is JsonNull ||
      this is JsonBool ||
      this is JsonNumber ||
      this is JsonString;
}

final class JsonNull extends JsonValue {
  const JsonNull();
}

final class JsonBool extends JsonValue {
  final bool value;
  const JsonBool(this.value);
}

final class JsonNumber extends JsonValue {
  final num value;
  const JsonNumber(this.value);
}

final class JsonString extends JsonValue {
  final String value;
  const JsonString(this.value);
}

final class JsonArray extends JsonValue {
  final List<JsonValue> items;
  const JsonArray(this.items);
  bool get isEmpty => items.isEmpty;
  int get length => items.length;
}

final class JsonObject extends JsonValue {
  final Map<String, JsonValue> fields;
  const JsonObject(this.fields);
  bool get isEmpty => fields.isEmpty;
  int get length => fields.length;
}
