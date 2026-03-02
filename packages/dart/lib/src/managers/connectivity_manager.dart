/// Abstract interface for network connectivity observation.
///
/// `ConnectivityManager` is a pure signal provider: it emits [NetworkStatus]
/// changes and exposes the current status, but it never interacts with
/// [QoraClient] directly. All reconnect logic (query replay, offline mutation
/// queue replay, thundering-herd batching) lives in `QoraClient` itself, which
/// subscribes to this manager via `QoraClient.attachConnectivityManager()`.
///
/// ## Implementing a custom manager
///
/// ```dart
/// class MyConnectivityManager extends ConnectivityManager {
///   final _controller = StreamController<NetworkStatus>.broadcast();
///   NetworkStatus _current = NetworkStatus.unknown;
///
///   @override
///   Stream<NetworkStatus> get statusStream => _controller.stream;
///
///   @override
///   NetworkStatus get currentStatus => _current;
///
///   @override
///   Future<void> start() async {
///     // Subscribe to your platform connectivity source here.
///     // Emit to _controller whenever status changes.
///   }
///
///   @override
///   void dispose() => _controller.close();
/// }
/// ```
///
/// ## Flutter
///
/// The `flutter_qora` package ships `FlutterConnectivityManager`, powered by
/// `connectivity_plus`, as a ready-to-use implementation. Pass it to
/// `QoraScope.connectivityManager` — `QoraScope` calls [start] and wires the
/// manager to the client automatically.
abstract class ConnectivityManager {
  /// Broadcast stream that emits a new [NetworkStatus] whenever connectivity
  /// changes.
  ///
  /// Subscribers receive updates as long as [start] has been called and
  /// [dispose] has not yet been called. The stream must be a broadcast stream
  /// so that multiple listeners (e.g. `QoraClient` and `NetworkStatusBuilder`)
  /// can subscribe independently.
  Stream<NetworkStatus> get statusStream;

  /// The most recently observed network status.
  ///
  /// Returns [NetworkStatus.unknown] before [start] is called or when the
  /// platform cannot determine connectivity state.
  NetworkStatus get currentStatus;

  /// Starts listening to the underlying connectivity source.
  ///
  /// Must be called before [statusStream] emits any events. Implementations
  /// should perform an initial status check and emit it on [statusStream] so
  /// that subscribers have an up-to-date value immediately after subscribing.
  ///
  /// Safe to call multiple times — subsequent calls should be no-ops if
  /// already started.
  Future<void> start();

  /// Stops listening and releases all resources.
  ///
  /// After calling [dispose], [statusStream] will no longer emit events and
  /// [currentStatus] may return stale data. Do not call [start] again after
  /// disposing.
  void dispose();
}

/// The network reachability status reported by a [ConnectivityManager].
///
/// Note that `online` reflects **interface availability** (a network interface
/// is active), not actual internet reachability. A device connected to a
/// router with no WAN access will report [online]. For reachability validation
/// add a health-check in your [ConnectivityManager] implementation.
enum NetworkStatus {
  /// At least one network interface is active.
  online,

  /// All network interfaces are down.
  offline,

  /// Connectivity state has not yet been determined, or no
  /// [ConnectivityManager] is registered.
  unknown,
}
