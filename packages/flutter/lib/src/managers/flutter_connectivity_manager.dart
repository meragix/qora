import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:qora/qora.dart';

/// Flutter implementation of [ConnectivityManager].
///
/// Listens to network connectivity changes via the `connectivity_plus` package
/// and invalidates all cached queries when the device reconnects after being
/// offline.
///
/// ## Setup
///
/// Pass an instance to [QoraScope]:
///
/// ```dart
/// final client = QoraClient();
///
/// QoraScope(
///   client: client,
///   connectivityManager: FlutterConnectivityManager(qoraClient: client),
///   child: MyApp(),
/// )
/// ```
///
/// ## Dependency
///
/// Add `connectivity_plus` to your `pubspec.yaml`:
/// ```yaml
/// dependencies:
///   connectivity_plus: ^6.0.0
/// ```
class FlutterConnectivityManager implements ConnectivityManager {
  final QoraClient _qoraClient;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  NetworkStatus _currentStatus = NetworkStatus.unknown;

  final _statusController = StreamController<NetworkStatus>.broadcast();

  @override
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  @override
  NetworkStatus get currentStatus => _currentStatus;

  FlutterConnectivityManager({required QoraClient qoraClient})
      : _qoraClient = qoraClient;

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
    final wasOffline = _currentStatus == NetworkStatus.offline;

    final isOnline = results.any((r) => r != ConnectivityResult.none);
    final newStatus = isOnline ? NetworkStatus.online : NetworkStatus.offline;

    if (_currentStatus == newStatus) return;

    _currentStatus = newStatus;
    _statusController.add(newStatus);

    if (wasOffline && newStatus == NetworkStatus.online) {
      // Invalidate all cached queries on reconnect. Active QoraBuilder widgets
      // detect the resulting Loading(previousData: …) state and trigger a
      // re-fetch automatically.
      _qoraClient.invalidateWhere((_) => true);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
