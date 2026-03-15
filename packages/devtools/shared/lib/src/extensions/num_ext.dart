/// Extensions on [int], [int?] for DevTools UI convenience.
extension IntExt on int {
  /// Formats a remaining-time duration (in milliseconds) into a short string.
  ///
  /// Typically used for stale-time and GC-time countdown display.
  ///
  /// - `<= 0` (and [showExpired] is true) → `'expired'`
  /// - `> 0` and `< 1s` → `'< 1s'`
  /// - `< 60s` → `'42s'`
  /// - `>= 60s` → `'2m 5s'`
  String fmtQueryTime([bool showExpired = true]) {
    if (showExpired && this <= 0) return 'expired';

    final duration = Duration(milliseconds: this);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    if (this > 0 && this < 1000) return '< 1s';
    if (minutes == 0) return '${seconds}s';

    return '${minutes}m ${seconds}s';
  }

  /// Formats a millisecond timestamp as a relative "time ago" string.
  ///
  /// [this] is expected to be a Unix timestamp in milliseconds.
  ///
  /// - `< 60s` → `'5s ago'`
  /// - `< 60m` → `'3m ago'`
  /// - else → `'2h ago'`
  String fmtTimeAgo() {
    final seconds = (DateTime.now().millisecondsSinceEpoch - this) ~/ 1000;
    if (seconds < 60) return '${seconds}s ago';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';
    return '${minutes ~/ 60}h ago';
  }

  /// Formats a fetch/operation duration in milliseconds as a short string.
  ///
  /// Typically used for the `fetchDurationMs` field on query events.
  ///
  /// - `< 1` → `'< 1ms'`
  /// - `< 1000` → `'42ms'`
  /// - `< 60s` → `'1.2s'`
  /// - `>= 60s` → `'2m 5s'`
  String fmtDurationMs() {
    if (this < 1) return '< 1ms';
    if (this < 1000) return '${this}ms';
    final secs = this / 1000.0;
    if (secs < 60) return '${secs.toStringAsFixed(1)}s';
    final m = secs ~/ 60;
    final s = (secs % 60).round();
    return '${m}m ${s}s';
  }

  /// Formats a byte count as a human-readable size string.
  ///
  /// Typically used for lazy payload size display.
  ///
  /// - `< 1 KB` → `'512 B'`
  /// - `< 1 MB` → `'12.3 KB'`
  /// - else → `'3.4 MB'`
  String fmtBytes() {
    if (this < 1024) return '$this B';
    if (this < 1024 * 1024) return '${(this / 1024).toStringAsFixed(1)} KB';
    return '${(this / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Converts this millisecond timestamp to a [DateTime].
  DateTime toDateTime() => DateTime.fromMillisecondsSinceEpoch(this);
}

extension NullableIntExt on int? {
  /// Falls back to [fallback] when null.
  int orDefault([int fallback = 0]) => this == null ? fallback : this!;

  /// Converts this nullable millisecond timestamp to a [DateTime], or null.
  DateTime? toNullOrDateTime() =>
      this == null ? null : DateTime.fromMillisecondsSinceEpoch(this!);
}
