import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:qora_flutter/qora_flutter.dart';

/// The device's network, switched from the UI.
///
/// It outlives the [QoraScope]: a simulated restart disposes the scope and its
/// [ConnectivityManager], but the device stays offline or online, and the
/// fake API keeps failing or answering accordingly.
class SimulatedNetwork extends ChangeNotifier {
  bool _offline = false;

  bool get isOffline => _offline;

  void toggle() {
    _offline = !_offline;
    notifyListeners();
  }
}

/// A [ConnectivityManager] that reports [SimulatedNetwork].
///
/// Used so the demo is self-contained: no need to disable Wi-Fi to see
/// offline behaviour. In a real app, use [FlutterConnectivityManager] (backed
/// by `connectivity_plus`), or `QoraScope.auto`.
class SimulatedConnectivityManager implements ConnectivityManager {
  SimulatedConnectivityManager(this._network) {
    _network.addListener(_emit);
  }

  final SimulatedNetwork _network;

  final StreamController<NetworkStatus> _controller =
      StreamController<NetworkStatus>.broadcast();

  @override
  Stream<NetworkStatus> get statusStream => _controller.stream;

  @override
  NetworkStatus get currentStatus =>
      _network.isOffline ? NetworkStatus.offline : NetworkStatus.online;

  @override
  Future<void> start() async => _emit();

  void _emit() {
    if (!_controller.isClosed) _controller.add(currentStatus);
  }

  @override
  void dispose() {
    _network.removeListener(_emit);
    _controller.close();
  }
}
