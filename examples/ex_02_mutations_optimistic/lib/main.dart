import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qora_devtools_extension/qora_devtools_extension.dart';
import 'package:qora_devtools_overlay/qora_devtools_overlay.dart';
import 'package:qora_flutter/qora_flutter.dart';

import 'screens/user_list_screen.dart';

void main() {
  final tracker = OverlayTracker();
  final tracker2 = VmTracker();
  final qoraClient = QoraClient(
    config: const QoraClientConfig(
      defaultOptions: QoraOptions(
        staleTime: Duration(minutes: 5),
        cacheTime: Duration(minutes: 10),
      ),
      debugMode: kDebugMode,
    ),
    tracker: kDebugMode ? tracker2 : null,
  );

  runApp(
    QoraInspector(
      tracker: tracker,
      client: kDebugMode ? qoraClient : null,
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
        title: 'Qora — Optimistic Mutations',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
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
        title: const Text('Qora — Optimistic Mutations'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExampleCard(
            title: 'Rename User',
            description:
                'Edit a user name with optimistic cache update. '
                'Rolls back automatically on server error (~30 % failure rate).',
            icon: Icons.edit_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const UserListScreen()),
            ),
          ),
          const SizedBox(height: 20),
          const _InfoCard(
            title: 'What This Demonstrates',
            items: [
              '• QoraMutationBuilder<TData, TVariables, TContext> full lifecycle',
              '• onMutate: snapshot + setQueryData (optimistic update)',
              '• onError: restoreQueryData (automatic rollback)',
              '• onSuccess: invalidateWhere (server reconciliation)',
              '• MutationState pattern matching: Idle / Pending / Success / Failure',
              '• Cross-cache optimistic update: list + detail simultaneously',
              '• QoraBuilder + QoraMutationBuilder composed on one screen',
            ],
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Try This',
            items: [
              '1. Tap the edit icon on any user',
              '2. Type a new name and tap Save',
              '3. The list updates instantly before the server responds',
              '4. ~30 % of saves fail: the name reverts to the original automatically',
              '5. On success: the name persists and is confirmed by the server',
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

  const _ExampleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

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
                child: Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  item,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
