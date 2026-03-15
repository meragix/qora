import 'dart:convert';

/// Extensions on [String] and [String?] for DevTools UI convenience.
extension StringExt on String {
  /// Formats a JSON-encoded query key into a human-readable breadcrumb string.
  ///
  /// The string must be a JSON-encoded list (e.g. `'["users",{"id":1}]'`).
  /// Each part is stringified; maps/lists are JSON-encoded inline.
  /// Parts are joined with `' › '`.
  ///
  /// Example: `'["users",{"id":1}]'.fmtQueryKey()` → `'users › {"id":1}'`
  String fmtQueryKey() {
    if (isEmpty) return '';
    final list = jsonDecode(this);

    if (list is! Iterable) return list.toString();

    return list.map((part) {
      if (part is Map || part is List) return jsonEncode(part);
      return part.toString();
    }).join('  ›  ');
  }

  /// Formats a JSON-encoded key into a bracket notation: `[ "user", "42" ]`.
  ///
  /// Falls back to the raw string if decoding fails.
  String fmtKey() {
    try {
      final decoded = jsonDecode(this) as List<dynamic>;
      final parts = decoded.map((e) => e is String ? '"$e"' : '$e').join(', ');
      return '[ $parts ]';
    } catch (_) {
      return this;
    }
  }

  /// Truncates this string to [max] characters, appending `'…'` when cut.
  String truncate({required int max}) =>
      length > max ? '${substring(0, max)}…' : this;
}

extension NullableStringExt on String? {
  /// Falls back to [fallback] when null or blank.
  String orDefault([String fallback = '']) =>
      (this == null || this!.trim().isEmpty) ? fallback : this!;
}
