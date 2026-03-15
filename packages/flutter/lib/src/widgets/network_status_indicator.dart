import 'package:flutter/widgets.dart';
import 'package:qora/qora.dart';

import 'network_status_builder.dart';

/// A widget that overlays an offline banner on top of [child] when the device
/// loses connectivity.
///
/// Wraps [NetworkStatusBuilder] with a pre-built default banner and a
/// [builder] escape-hatch for full customisation. Place it near the root of
/// your widget tree (inside [QoraScope]) to provide app-wide offline
/// feedback.
///
/// ## Default banner
///
/// ```dart
/// QoraScope(
///   client: client,
///   connectivityManager: FlutterConnectivityManager(),
///   child: NetworkStatusIndicator(
///     child: MyApp(),
///   ),
/// )
/// ```
///
/// Renders a thin dark bar at the bottom of the screen saying "Offline mode"
/// when [NetworkStatus.offline] is detected.
///
/// ## Custom banner
///
/// Override the offline UI entirely with [offlineBanner]:
///
/// ```dart
/// NetworkStatusIndicator(
///   offlineBanner: (context) => Container(
///     color: Colors.red,
///     padding: const EdgeInsets.all(8),
///     child: const Text('No connection', style: TextStyle(color: Colors.white)),
///   ),
///   child: MyApp(),
/// )
/// ```
///
/// ## Full builder control
///
/// Use [builder] when you need to react to every [NetworkStatus] value
/// (including [NetworkStatus.online] and [NetworkStatus.unknown]):
///
/// ```dart
/// NetworkStatusIndicator(
///   builder: (context, status, child) {
///     return Stack(
///       children: [
///         child!,
///         if (status == NetworkStatus.offline)
///           const Positioned(
///             bottom: 0,
///             left: 0,
///             right: 0,
///             child: OfflineBanner(),
///           ),
///       ],
///     );
///   },
///   child: MyApp(),
/// )
/// ```
class NetworkStatusIndicator extends StatelessWidget {
  /// The main content of the app.
  final Widget child;

  /// Custom builder that receives the full [NetworkStatus] and [child].
  ///
  /// When provided, [offlineBanner] is ignored — use [builder] for complete
  /// control over how each status is rendered.
  final Widget Function(
    BuildContext context,
    NetworkStatus status,
    Widget? child,
  )? builder;

  /// Widget shown as an overlay when [NetworkStatus.offline] is detected.
  ///
  /// Placed at the bottom of the screen by the default [builder].
  /// Ignored when a custom [builder] is provided.
  final Widget Function(BuildContext context)? offlineBanner;

  const NetworkStatusIndicator({
    super.key,
    required this.child,
    this.builder,
    this.offlineBanner,
  });

  @override
  Widget build(BuildContext context) {
    return NetworkStatusBuilder(
      builder: builder ?? _defaultBuilder,
      child: child,
    );
  }

  Widget _defaultBuilder(
    BuildContext context,
    NetworkStatus status,
    Widget? child,
  ) {
    if (status != NetworkStatus.offline) return child!;

    final banner = offlineBanner?.call(context) ?? _DefaultOfflineBanner();

    return Stack(
      children: [
        child!,
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: banner,
        ),
      ],
    );
  }
}

/// Minimal default offline banner.
///
/// Rendered as a semi-transparent dark bar at the bottom of the screen.
/// Replace it via [NetworkStatusIndicator.offlineBanner] or
/// [NetworkStatusIndicator.builder].
class _DefaultOfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC000000),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              // Uses codepoint for wifi_off — no material dependency required.
              IconData(0xe6eb, fontFamily: 'MaterialIcons'),
              color: Color(0xFFFFFFFF),
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'Offline mode',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
