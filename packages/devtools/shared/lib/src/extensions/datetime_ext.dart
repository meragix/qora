/// Extensions on [DateTime] and [DateTime?] for DevTools UI convenience.
extension DateTimeExt on DateTime {
  /// Milliseconds since epoch — convenience alias for [millisecondsSinceEpoch].
  int get epochMs => millisecondsSinceEpoch;

  /// Formats as `HH:mm:ss.mmm` for inspector metadata rows.
  ///
  /// Example: `DateTime(2024, 1, 1, 9, 5, 3, 42).fmtDateTime()` → `'09:05:03.042'`
  String fmtDateTime() {
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    final ss = second.toString().padLeft(2, '0');
    final ms = millisecond.toString().padLeft(3, '0');
    return '$hh:$mm:$ss.$ms';
  }
}

extension NullableDateTimeExt on DateTime? {
  /// Falls back to [fallback] (or [DateTime.now] when omitted) when null.
  DateTime orDefault([DateTime? fallback]) =>
      this ?? fallback ?? DateTime.now();
}
