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

  /// Formats as `MM/D HH:mm:ss` for devtools metadata.
  ///
  /// Example: `DateTime(2026, 3, 16, 9, 5, 22).fmtDateTime()` → `'03/16 09:05:22'`
  String fmtDateTime2([bool showMonthDay = true]) {
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    final ss = second.toString().padLeft(2, '0');
    if (!showMonthDay) {
      return '$hh:$mm:$ss';
    }
    final month = hour.toString().padLeft(2, '0');
    final day = hour.toString().padLeft(2, '0');
    return '$month/$day $hh:$mm:$ss';
  }
}

extension NullableDateTimeExt on DateTime? {
  /// Falls back to [fallback] (or [DateTime.now] when omitted) when null.
  DateTime orDefault([DateTime? fallback]) =>
      this ?? fallback ?? DateTime.now();
}
