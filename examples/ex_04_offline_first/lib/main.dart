import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import 'core/persistence/serializers.dart';
import 'features/todos/data/todo_api.dart';
import 'features/todos/ui/todo_screen.dart';
import 'shared/connectivity/simulated_connectivity_manager.dart';
import 'shared/widgets/offline_banner.dart';

/// Bootstrap:
/// 1. Open [InMemoryStorageAdapter] (swap for Hive/Isar in a real app).
/// 2. Build [PersistQoraClient] with [NetworkMode.offlineFirst] and the
///    default [OfflineMutationQueue] (stopOnFirstError: true) so writes
///    survive offline periods in FIFO order.
/// 3. Register serializers for every type written to disk.
/// 4. Warm the cache via [PersistQoraClient.hydrate] **before** [runApp]
///    so returning users see their data on the very first frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = InMemoryStorageAdapter();
  await storage.init();

  final api = TodoApi();
  final connectivity = SimulatedConnectivityManager(api);

  final client = PersistQoraClient(
    storage: storage,
    persistDuration: const Duration(days: 30),
    config: QoraClientConfig(
      defaultOptions: const QoraOptions(
        staleTime: Duration(minutes: 5),
        networkMode: NetworkMode.offlineFirst,
      ),
      // Prevent thundering-herd on reconnect: 3 concurrent, 150 ms jitter.
      reconnectStrategy: const ReconnectStrategy(
        maxConcurrent: 3,
        jitter: Duration(milliseconds: 150),
      ),
      debugMode: kDebugMode,
    ),
  );

  registerAllSerializers(client);

  // Warm cache from disk before the first frame — no spinner for returning users.
  await client.hydrate();

  runApp(
    QoraScope(
      client: client,
      lifecycleManager: FlutterLifecycleManager(qoraClient: client),
      connectivityManager: connectivity,
      child: OfflineBannerWrapper(
        child: _App(api: api, connectivity: connectivity),
      ),
    ),
  );
}

class _App extends StatelessWidget {
  final TodoApi api;
  final SimulatedConnectivityManager connectivity;

  const _App({required this.api, required this.connectivity});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline-First Todos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: _HomeScreen(api: api, connectivity: connectivity),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  final TodoApi api;
  final SimulatedConnectivityManager connectivity;

  const _HomeScreen({required this.api, required this.connectivity});

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isOffline = widget.connectivity.isOffline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline-First Todos'),
        actions: [
          // ── Connectivity toggle ─────────────────────────────────────────
          Tooltip(
            message: isOffline ? 'Go online' : 'Simulate offline',
            child: IconButton(
              icon: Icon(isOffline ? Icons.wifi_off : Icons.wifi),
              color: isOffline ? Colors.amber.shade700 : null,
              onPressed: () {
                widget.connectivity.toggle();
                setState(() {}); // refresh AppBar icon
              },
            ),
          ),
        ],
      ),
      body: TodoScreen(api: widget.api),
    );
  }
}
