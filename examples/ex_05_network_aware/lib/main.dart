import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import 'features/feed/data/feed_api.dart';
import 'features/feed/ui/compose_screen.dart';
import 'features/feed/ui/feed_screen.dart';
import 'shared/connectivity/simulated_connectivity_manager.dart';
import 'shared/widgets/offline_banner.dart';

/// Bootstrap:
/// - [QoraClient] with [NetworkMode.online] as global default so queries
///   pause automatically when offline.
/// - [ReconnectStrategy] with maxConcurrent + jitter to prevent
///   thundering-herd on reconnect.
/// - [SimulatedConnectivityManager] — toggle offline/online via the AppBar
///   button (swap for [FlutterConnectivityManager] in a real app).
/// - [NetworkStatusIndicator] wraps the app for a zero-config offline banner.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final api = FeedApi();
  final connectivity = SimulatedConnectivityManager();

  final client = QoraClient(
    config: QoraClientConfig(
      defaultOptions: const QoraOptions(
        // Default: pause when offline, replay automatically on reconnect.
        networkMode: NetworkMode.online,
        staleTime: Duration(minutes: 5),
      ),
      // Replay paused queries in batches of 5 with up to 200 ms jitter.
      // Prevents 20+ simultaneous requests after coming back online.
      reconnectStrategy: const ReconnectStrategy(
        maxConcurrent: 5,
        jitter: Duration(milliseconds: 200),
      ),
      debugMode: kDebugMode,
    ),
  );

  runApp(
    QoraScope(
      client: client,
      connectivityManager: connectivity,
      lifecycleManager: FlutterLifecycleManager(qoraClient: client),
      child: OfflineBannerWrapper(
        child: _App(api: api, connectivity: connectivity),
      ),
    ),
  );
}

class _App extends StatelessWidget {
  final FeedApi api;
  final SimulatedConnectivityManager connectivity;

  const _App({required this.api, required this.connectivity});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Awareness',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: _HomeScreen(api: api, connectivity: connectivity),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  final FeedApi api;
  final SimulatedConnectivityManager connectivity;

  const _HomeScreen({required this.api, required this.connectivity});

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final isOffline = widget.connectivity.isOffline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Awareness'),
        actions: [
          // ── Connectivity toggle ─────────────────────────────────────────
          Tooltip(
            message: isOffline ? 'Go online' : 'Simulate offline',
            child: IconButton(
              icon: Icon(isOffline ? Icons.wifi_off : Icons.wifi),
              color: isOffline ? Colors.amber.shade700 : null,
              onPressed: () {
                widget.connectivity.toggle();
                setState(() {});
              },
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          FeedScreen(api: widget.api),
          ComposeScreen(api: widget.api),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dynamic_feed), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.edit), label: 'Compose'),
        ],
      ),
    );
  }
}
