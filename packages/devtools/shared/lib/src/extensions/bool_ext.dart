/// Extensions on [bool] and [bool?] for DevTools UI convenience.
extension BoolExt on bool {
  /// Returns `1` for `true`, `0` for `false`.
  ///
  /// Useful when building numeric expressions from flag fields.
  int toInt() => this ? 1 : 0;

  /// Returns [ifTrue] when this is `true`, [ifFalse] otherwise.
  ///
  /// Example: `isEnabled.label('enabled', 'disabled')` → `'enabled'`
  String label(String ifTrue, String ifFalse) => this ? ifTrue : ifFalse;
}

extension NullableBoolExt on bool? {
  /// Falls back to [fallback] when null.
  bool orDefault([bool fallback = false]) => this == null ? fallback : this!;
}
