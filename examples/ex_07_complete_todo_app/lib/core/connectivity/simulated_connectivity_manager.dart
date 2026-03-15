import 'dart:async';

import 'package:qora_flutter/qora_flutter.dart';

/// A [ConnectivityManager] whose online/offline state is toggled from the UI.
///
/// Used in this example so the demo is self-contained — no need to actually
/// disable WiFi to see offline behaviour. Press the antenna button in the
/// AppBar to toggle.
///
/// In a real app, replace this with [FlutterConnectivityManager] (backed by
/// `connectivity_plus`).
class SimulatedConnectivityManager implements ConnectivityManager {
  final StreamController<NetworkStatus> _controller =
      StreamController<NetworkStatus>.broadcast();

  NetworkStatus _current = NetworkStatus.online;

  @override
  Stream<NetworkStatus> get statusStream => _controller.stream;

  @override
  NetworkStatus get currentStatus => _current;

  @override
  Future<void> start() async {
    // Emit the initial status so QoraClient has a baseline immediately.
    _controller.add(_current);
  }

  /// Toggle between online and offline.
  void toggle() {
    _current = _current == NetworkStatus.online
        ? NetworkStatus.offline
        : NetworkStatus.online;
    _controller.add(_current);
  }

  bool get isOffline => _current == NetworkStatus.offline;

  @override
  void dispose() => _controller.close();
}
