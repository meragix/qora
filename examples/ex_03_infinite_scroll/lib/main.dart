import 'package:ex_03_infinite_scroll/features/feed/ui/feed_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

void main() {
  final qoraClient = QoraClient(
    config: const QoraClientConfig(
      defaultOptions: QoraOptions(staleTime: Duration(minutes: 2), cacheTime: Duration(minutes: 10)),
      debugMode: kDebugMode,
    ),
  );

  runApp(MyApp(qoraClient: qoraClient));
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
        title: 'Qora — Infinite Scroll',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
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
        title: const Text('Qora — Infinite Scroll'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExampleCard(
            title: 'Social Feed',
            description:
                'Cursor-based infinite scroll with maxPages windowing, '
                'pull-to-refresh, and optimistic post creation.',
            icon: Icons.dynamic_feed_outlined,
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const FeedScreen())),
          ),
          const SizedBox(height: 20),
          const _InfoCard(
            title: 'What This Demonstrates',
            items: [
              '• InfiniteQueryBuilder — manages pagination lifecycle',
              '• Cursor-based pagination — stable results despite server inserts',
              '• maxPages: 3 — bounds in-memory page window; drops oldest on overflow',
              '• hasPreviousPage — detects eviction and re-fetches from top on scroll back',
              '• isFetchingNextPage / isFetchingPreviousPage — per-direction spinners',
              '• InfiniteData.flatten() — converts page matrix to flat item list',
              '• setInfiniteQueryData — optimistic post prepend with rollback on failure',
              '• observer.refetch() — re-fetches all pages without losing scroll position',
              '• InfiniteFailure.previousData — load-more errors keep feed visible',
            ],
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Try This',
            items: [
              '1. Open the Feed — watch first page load',
              '2. Scroll to the bottom — pages load automatically (scroll trigger)',
              '3. Load 4 pages — page 1 is evicted (maxPages: 3 windowing)',
              '4. Scroll back to the top — hasPreviousPage triggers re-fetch of page 1',
              '5. Pull down to refresh — refetch() re-validates all loaded pages',
              '6. Tap + to compose — post appears instantly (optimistic)',
              '7. ~20% of posts fail — optimistic item rolls back automatically',
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
