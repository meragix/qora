import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:qora/qora.dart';

/// Flutter implementation of [ConnectivityManager].
///
/// Listens to network connectivity changes via the `connectivity_plus` package
/// and emits [NetworkStatus] events on [statusStream].
///
/// ## Responsibilities
///
/// [FlutterConnectivityManager] is a **pure signal provider** — it converts
/// `connectivity_plus` events into [NetworkStatus] values and nothing else.
/// All reconnect logic (query replay, mutation queue replay, thundering-herd
/// batching) is handled by [QoraClient] via
/// [QoraClient.attachConnectivityManager], called automatically by
/// [QoraScope].
///
/// ## Setup
///
/// Pass an instance to [QoraScope] — no [QoraClient] reference is needed:
///
/// ```dart
/// void main() {
///   final client = QoraClient();
///
///   runApp(
///     QoraScope(
///       client: client,
///       connectivityManager: FlutterConnectivityManager(),
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
///
/// [QoraScope] calls [start] automatically, then attaches this manager to
/// [QoraClient] via [QoraClient.attachConnectivityManager], and calls
/// [dispose] when unmounted.
///
/// ## Dependency
///
/// Add `connectivity_plus` to your `pubspec.yaml`:
/// ```yaml
/// dependencies:
///   connectivity_plus: ^6.0.0
/// ```
class FlutterConnectivityManager implements ConnectivityManager {
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  NetworkStatus _currentStatus = NetworkStatus.unknown;

  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();

  @override
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  @override
  NetworkStatus get currentStatus => _currentStatus;

  FlutterConnectivityManager();

  @override
  Future<void> start() async {
    final initialResults = await _connectivity.checkConnectivity();
    _updateStatus(initialResults);

    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateStatus,
      // ignore: avoid_print
      onError: (Object error) => print('[Qora] Connectivity error: $error'),
    );
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final newStatus = results.any((r) => r != ConnectivityResult.none)
        ? NetworkStatus.online
        : NetworkStatus.offline;

    if (_currentStatus == newStatus) return;

    _currentStatus = newStatus;
    // Emit the new status — QoraClient reacts via its subscription.
    _statusController.add(newStatus);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
