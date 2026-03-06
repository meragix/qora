import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/qora_devtools_overlay.dart';
import 'package:qora_flutter/qora_flutter.dart';
import 'screens/user_detail_screen.dart';
import 'screens/user_list_screen.dart';

void main() {
  final tracker = OverlayTracker();
  final qoraClient = QoraClient(
    config: const QoraClientConfig(
      defaultOptions: QoraOptions(staleTime: Duration(minutes: 5), cacheTime: Duration(minutes: 10)),
      debugMode: kDebugMode,
    ),
    tracker: kDebugMode ? tracker : null,
  );

  runApp(
    QoraInspector(
      tracker: tracker,
      child: MyApp(qoraClient: qoraClient),
    ),
  );
}

class MyApp extends StatelessWidget {
  final QoraClient qoraClient;

  const MyApp({super.key, required this.qoraClient});

  @override
  Widget build(BuildContext context) {
    return QoraScope(
      client: qoraClient,
      lifecycleManager: FlutterLifecycleManager(qoraClient: qoraClient),
      connectivityManager: FlutterConnectivityManager(),
      child: MaterialApp(
        title: 'Qora Basic Query',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qora — Basic Query'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExampleCard(
            title: 'User List',
            description: 'Fetch a list with SWR caching, pull-to-refresh, and background revalidation.',
            icon: Icons.people,
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const UserListScreen())),
          ),
          const SizedBox(height: 12),
          _ExampleCard(
            title: 'User Detail',
            description: 'Per-item query — shows previousData during refresh and updatedAt timestamp.',
            icon: Icons.person,
            onTap: () =>
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const UserDetailScreen(userId: '1'))),
          ),
          const SizedBox(height: 20),
          const _InfoCard(
            title: 'What This Demonstrates',
            items: [
              '• QoraScope + FlutterLifecycleManager + FlutterConnectivityManager setup',
              '• QoraBuilder with correct 3-arg builder (context, state, fetchStatus)',
              '• switch (state) pattern matching on QoraState sealed class',
              '• Stale-while-revalidate: instant load from cache on re-navigation',
              '• FetchStatus.fetching banner during background revalidation',
              '• Graceful degradation: stale data visible during refresh',
              '• Pull-to-refresh via invalidate()',
              '• Per-item query with previousData and updatedAt',
            ],
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Try This',
            items: [
              '1. Open User List — wait for load',
              '2. Go back and reopen — instant from cache',
              '3. Pull to refresh — see stale data + fetching banner',
              '4. Open a user, go back, reopen — instant from cache',
              '5. Wait 5 min — data goes stale, background refetch fires on reopen',
            ],
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ExampleCard({required this.title, required this.description, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(description, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const _InfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(item, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
