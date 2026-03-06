import 'dart:convert';

/// Formats a query key list into a human-readable string.
///
/// Each part is stringified; maps/lists are JSON-encoded.
/// Parts are joined with ' › '.
///
/// Example: `['users', {'id': 1}]` → `'users › {"id":1}'`
String formatQueryKey(dynamic key) {
  final list = key is String ? jsonDecode(key) : key;

  if (list is! Iterable) return list.toString();

  return list.map((part) {
    if (part is Map || part is List) return jsonEncode(part);
    return part.toString();
  }).join('  ›  ');
}

/// Formats a remaining-time duration (in milliseconds) into a short string.
///
/// - `<= 0` → `'expired'`
/// - `< 60s` → `'42s'`
/// - `>= 60s` → `'2m 5s'`
String formatQueryTime(int ms) {
  if (ms <= 0) return 'expired';
  final seconds = ms ~/ 1000;
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  return '${minutes}m ${seconds % 60}s';
}
