import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import 'core/auth/auth_service.dart';
import 'core/connectivity/simulated_connectivity_manager.dart';
import 'core/persistence/hive_storage_adapter.dart';
import 'core/persistence/serializers.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/todos/data/todo_api.dart';
import 'features/todos/ui/todo_list_screen.dart';
import 'shared/widgets/offline_banner.dart';

/// Bootstrap:
/// 1. Open [HiveStorageAdapter] — initialises Hive paths for the platform.
/// 2. Build [PersistQoraClient] with [NetworkMode.offlineFirst] so cached data
///    is served instantly and revalidation happens in the background.
/// 3. Register serializers so [AuthUser] survives app restarts.
/// 4. Warm the cache via [PersistQoraClient.hydrate] before [runApp]
///    so returning users see their data on the very first frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await HiveStorageAdapter.open('qora_cache');
  final connectivity = SimulatedConnectivityManager();
  final auth = AuthService();

  final client = PersistQoraClient(
    storage: storage,
    persistDuration: const Duration(days: 7),
    config: QoraClientConfig(
      defaultOptions: const QoraOptions(
        networkMode: NetworkMode.offlineFirst,
        staleTime: Duration(minutes: 5),
      ),
      reconnectStrategy: const ReconnectStrategy(
        maxConcurrent: 3,
        jitter: Duration(milliseconds: 150),
      ),
      debugMode: kDebugMode,
    ),
  );

  registerAllSerializers(client);
  await client.hydrate();

  final api = TodoApi();

  runApp(
    QoraScope(
      client: client,
      lifecycleManager: FlutterLifecycleManager(qoraClient: client),
      connectivityManager: connectivity,
      child: OfflineBannerWrapper(
        child: _App(auth: auth, api: api, connectivity: connectivity),
      ),
    ),
  );
}

class _App extends StatelessWidget {
  final AuthService auth;
  final TodoApi api;
  final SimulatedConnectivityManager connectivity;

  const _App({
    required this.auth,
    required this.api,
    required this.connectivity,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qora Todos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: ValueListenableBuilder<AuthUser?>(
        valueListenable: auth,
        builder: (context, user, _) {
          if (user == null) {
            return LoginScreen(authService: auth);
          }
          return TodoListScreen(
            api: api,
            authService: auth,
            connectivity: connectivity,
          );
        },
      ),
    );
  }
}
