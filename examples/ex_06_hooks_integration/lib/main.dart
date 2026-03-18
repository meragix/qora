import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_hooks/qora_hooks.dart';
import 'features/posts/ui/posts_screen.dart';
import 'features/profile/ui/profile_screen.dart';
import 'shared/api/json_placeholder_api.dart';
import 'shared/widgets/app_progress_bar.dart';

void main() {
  final client = QoraClient();
  runApp(QoraScope(client: client, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hooks Integration',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const _HomeScreen(),
    );
  }
}

/// Root screen with bottom navigation.
///
/// The [AppBar] bottom uses [AppProgressBar] (backed by [useIsFetching]) to
/// show a global loading indicator without any per-screen coupling.
/// [useIsMutating] disables navigation while a mutation is in flight.
class _HomeScreen extends HookWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    final api = useMemoized(JsonPlaceholderApi.new);
    final selectedIndex = useState(0);
    final isMutating = useIsMutating();

    final screens = [
      ProfileScreen(userId: '1', api: api),
      PostsScreen(api: api),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hooks Integration'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(2),
          child: AppProgressBar(),
        ),
      ),
      body: screens[selectedIndex.value],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.value,
        // Disable tab switching while a mutation is pending to avoid
        // navigating away mid-save.
        onDestinationSelected: isMutating
            ? null
            : (i) => selectedIndex.value = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'Posts',
          ),
        ],
      ),
    );
  }
}
