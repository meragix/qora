import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import 'core/persistence/serializers.dart';
import 'features/sync/sync_panel.dart';
import 'features/todos/data/todo_api.dart';
import 'features/todos/data/todo_mutations.dart';
import 'features/todos/ui/todo_screen.dart';
import 'shared/connectivity/simulated_connectivity_manager.dart';
import 'shared/widgets/offline_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Swap for a disk-backed adapter (Hive, SharedPreferences...) in a real
  // app. In this demo, storage survives the simulated restart, not a real one.
  final storage = InMemoryStorageAdapter();
  await storage.init();

  final network = SimulatedNetwork();
  runApp(
    OfflineTodoApp(storage: storage, network: network, api: TodoApi(network)),
  );
}

/// Builds the client the way a real app does at startup.
///
/// Order matters: register serializers and mutations, then `hydrate()`, which
/// restores the cached list and then the queued writes, and starts sending
/// them.
Future<PersistQoraClient> startClient(
  StorageAdapter storage,
  TodoApi api,
) async {
  final client = PersistQoraClient(
    storage: storage,
    persistDuration: const Duration(days: 30),
    config: QoraClientConfig(
      defaultOptions: const QoraOptions(
        staleTime: Duration(minutes: 5),
        networkMode: NetworkMode.offlineFirst,
      ),
      // At most 3 concurrent requests on reconnect, 150 ms jitter.
      reconnectStrategy: const ReconnectStrategy(
        maxConcurrent: 3,
        jitter: Duration(milliseconds: 150),
      ),
      debugMode: kDebugMode,
    ),
  );
  registerAllSerializers(client);
  registerTodoMutations(client, api);
  await client.hydrate();
  return client;
}

/// The app, with a "restart" that rebuilds the client from storage.
///
/// [storage], [network] and [api] play the disk, the device's network and the
/// server: they outlive a restart. The client, the widgets and everything in
/// memory do not.
class OfflineTodoApp extends StatefulWidget {
  const OfflineTodoApp({
    super.key,
    required this.storage,
    required this.network,
    required this.api,
  });

  final StorageAdapter storage;
  final SimulatedNetwork network;
  final TodoApi api;

  @override
  State<OfflineTodoApp> createState() => _OfflineTodoAppState();
}

class _OfflineTodoAppState extends State<OfflineTodoApp> {
  PersistQoraClient? _client;
  SimulatedConnectivityManager? _connectivity;
  FlutterLifecycleManager? _lifecycle;
  int _session = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final client = await startClient(widget.storage, widget.api);
    if (!mounted) return client.dispose();
    setState(() {
      _client = client;
      // New managers per session: QoraScope disposes them with the client.
      _connectivity = SimulatedConnectivityManager(widget.network);
      _lifecycle = FlutterLifecycleManager(qoraClient: client);
      _session++;
    });
  }

  Future<void> _restart() async {
    // Unmounting QoraScope disposes the client: like a killed process, it
    // stops sending and keeps what it stored. Wait for that before the next
    // client reads storage.
    setState(() => _client = null);
    await WidgetsBinding.instance.endOfFrame;
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    if (client == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: Text('Starting...'))),
      );
    }
    return QoraScope(
      key: ValueKey(_session),
      client: client,
      lifecycleManager: _lifecycle,
      connectivityManager: _connectivity,
      child: MaterialApp(
        title: 'Offline-First Todos',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        builder: (context, child) => OfflineBannerWrapper(child: child!),
        home: _HomeScreen(
          api: widget.api,
          network: widget.network,
          onRestart: _restart,
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({
    required this.api,
    required this.network,
    required this.onRestart,
  });

  final TodoApi api;
  final SimulatedNetwork network;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline-First Todos'),
        actions: [
          const SyncButton(),
          ListenableBuilder(
            listenable: network,
            builder: (context, _) => IconButton(
              tooltip: network.isOffline ? 'Go online' : 'Simulate offline',
              icon: Icon(network.isOffline ? Icons.wifi_off : Icons.wifi),
              color: network.isOffline ? Colors.amber.shade700 : null,
              onPressed: network.toggle,
            ),
          ),
          IconButton(
            tooltip: 'Simulate an app restart',
            icon: const Icon(Icons.restart_alt),
            onPressed: onRestart,
          ),
        ],
      ),
      body: TodoScreen(api: api),
    );
  }
}
