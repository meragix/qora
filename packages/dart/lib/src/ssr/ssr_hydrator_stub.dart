import '../client/qora_client.dart';

/// No-op [SsrHydrator] for non-web platforms.
///
/// On native and server targets `window.__QORA_STATE__` does not exist, so
/// [hydrate] is a silent no-op. This lets library consumers import
/// [SsrHydrator] unconditionally; the conditional export in
/// `ssr_hydrator.dart` selects this stub on every platform except Flutter Web.
class SsrHydrator {
  /// Creates an [SsrHydrator].
  ///
  /// [client] is unused on non-web platforms but accepted so call-sites are
  /// identical across platforms.
  // ignore: avoid_unused_constructor_parameters
  const SsrHydrator(QoraClient client);

  /// No-op on non-web platforms. Returns immediately.
  ///
  /// On Flutter Web, the real implementation reads `window.__QORA_STATE__`
  /// and calls [QoraClient.queueHydration] for each entry. See
  /// `ssr_hydrator_web.dart`.
  void hydrate({
    Map<String, dynamic Function(dynamic)>? deserializers,
  }) {}
}
