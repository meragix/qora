import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

/// App-wide offline banner using [NetworkStatusIndicator].
///
/// Wraps [child] and overlays a custom amber bar at the bottom of the screen
/// whenever the device is offline.  Zero widget boilerplate — just wrap your
/// app's root and [NetworkStatusIndicator] handles the rest.
class OfflineBannerWrapper extends StatelessWidget {
  final Widget child;

  const OfflineBannerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return NetworkStatusIndicator(
      offlineBanner: (_) => const _OfflineBanner(),
      child: child,
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.amber.shade700,
      child: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 14, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Offline — queries paused, mutations queued',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
