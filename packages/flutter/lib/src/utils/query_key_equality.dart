import 'package:qora/qora.dart';

/// Returns `true` when [a] and [b] describe the same query key.
///
/// Widgets usually receive a freshly allocated list on every rebuild
/// (`queryKey: ['users', userId]`), so identity comparison would treat every
/// parent rebuild as a key change and re-subscribe. This compares the
/// normalised key content instead.
///
/// Internal to `qora_flutter`; not exported.
bool sameQueryKey(Object a, Object b) {
  if (identical(a, b)) return true;
  return QoraKey(normalizeKey(a)) == QoraKey(normalizeKey(b));
}
