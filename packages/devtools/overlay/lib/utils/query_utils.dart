import 'dart:convert';

/// Formats a query key list into a human-readable string.
///
/// Each part is stringified; maps/lists are JSON-encoded.
/// Parts are joined with ' › '.
///
/// Example: `['users', {'id': 1}]` → `'users › {"id":1}'`
String formatQueryKey(dynamic key) {
  if (key is String && key.isEmpty) return '';
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

  final duration = Duration(milliseconds: ms);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;

  if (ms > 0 && ms < 1000) return '< 1s';
  if (minutes == 0) return '${seconds}s';

  return '${minutes}m ${seconds}s';
}

/// Formats a [DateTime] as `HH:mm:ss.mmm` for inspector metadata rows.
String fmtDateTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}:'
    '${dt.second.toString().padLeft(2, '0')}.'
    '${dt.millisecond.toString().padLeft(3, '0')}';

String formatTimeAgo(int timestamp) {
  final seconds = (DateTime.now().millisecondsSinceEpoch - timestamp) ~/ 1000;
  if (seconds < 60) return '${seconds}s ago';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m ago';
  return '${minutes ~/ 60}h ago';
}

/// Formats the serialised key into a readable `[ "user", "42" ]` form.
String formatKey(String rawKey) {
  try {
    final decoded = jsonDecode(rawKey) as List<dynamic>;
    final parts = decoded.map((e) => e is String ? '"$e"' : '$e').join(', ');
    return '[ $parts ]';
  } catch (_) {
    return rawKey; // fallback if not valid JSON
  }
}
