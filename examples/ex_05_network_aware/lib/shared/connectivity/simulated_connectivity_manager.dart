import 'dart:async';

import 'package:qora_flutter/qora_flutter.dart';

/// A [ConnectivityManager] whose online/offline state is toggled from the UI.
///
/// Emits [NetworkStatus] events that [QoraClient] reacts to:
/// - Queries with [NetworkMode.online] pause when `offline` is emitted and
///   replay when `online` is emitted — **without the HTTP layer ever being
///   called** while offline.
/// - Offline mutations are enqueued and replayed in FIFO order on reconnect.
///
/// No [FeedApi] reference is needed because Qora intercepts before the fetcher
/// or mutator is called.  In a real app replace this with
/// [FlutterConnectivityManager] (backed by `connectivity_plus`).
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
    // Emit initial status so QoraClient has a baseline immediately.
    _controller.add(_current);
  }

  /// Toggle between online and offline, notifying [QoraClient] via the stream.
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
