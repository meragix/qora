// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qora/qora.dart';
import 'package:qora_devtools_overlay/qora_devtools_overlay.dart';

// ---------------------------------------------------------------------------
// App entry point
//
// OverlayTracker connects QoraClient to the in-app panel.
// QoraInspector wraps the app and injects the FAB + panel.
// In release builds both are zero-cost — QoraInspector returns child directly
// and QoraClient defaults to NoOpTracker.
// ---------------------------------------------------------------------------

void main() {
  // One shared tracker — both QoraClient and QoraInspector use the same instance.
  final tracker = OverlayTracker();

  final client = QoraClient(
    config: const QoraClientConfig(
      defaultOptions: QoraOptions(
        staleTime: Duration(minutes: 5),
        retryCount: 2,
      ),
    ),
    // Pass tracker only in debug — QoraClient falls back to NoOpTracker in release,
    // so no events are emitted and the ring-buffer stays empty.
    tracker: kDebugMode ? tracker : null,
  );

  runApp(
    // QoraInspector is a no-op wrapper in release builds — returns child directly.
    // In debug builds it adds a floating action button (bottom-right) that
    // opens a 3-column panel: Queries · Mutations · Timeline.
    QoraInspector(
      tracker: tracker,
      child: MyApp(client: client),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.client});

  final QoraClient client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'qora_devtools_overlay Demo',
      home: HomeScreen(client: client),
    );
  }
}

// ---------------------------------------------------------------------------
// Home screen — navigate to examples
// ---------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.client});

  final QoraClient client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qora Overlay Demo')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Query — user list'),
            subtitle: const Text('Tap "refresh" to trigger a fetch event'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, UserListScreen(client: client)),
          ),
          ListTile(
            title: const Text('Mutation — update user'),
            subtitle: const Text('Tap "Save" to trigger a mutation event'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, UpdateUserScreen(client: client)),
          ),
          ListTile(
            title: const Text('Optimistic update'),
            subtitle: const Text('Write data before the server responds'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, OptimisticScreen(client: client)),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

// ---------------------------------------------------------------------------
// Example 1 — useQuery: triggers query events in the overlay timeline
// ---------------------------------------------------------------------------

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key, required this.client});

  final QoraClient client;

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _usersFuture = widget.client.fetchQuery<List<User>>(
        key: const ['users'],
        fetcher: ApiService.getUsers,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          // Invalidate → the overlay panel shows a fetch event in the Timeline.
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              widget.client.invalidate(const ['users']);
              _load();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final users = snapshot.data ?? [];
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) => ListTile(
              leading: CircleAvatar(child: Text(users[i].name[0])),
              title: Text(users[i].name),
              subtitle: Text(users[i].email),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Example 2 — Mutation: appears in Mutations tab + Timeline
// ---------------------------------------------------------------------------

class UpdateUserScreen extends StatefulWidget {
  const UpdateUserScreen({super.key, required this.client});

  final QoraClient client;

  @override
  State<UpdateUserScreen> createState() => _UpdateUserScreenState();
}

class _UpdateUserScreenState extends State<UpdateUserScreen> {
  final _controller = TextEditingController(text: 'Alice');
  bool _pending = false;
  String? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _pending = true;
      _result = null;
    });

    // MutationController wires into QoraTracker automatically.
    // The overlay panel shows the mutation in the Mutations tab while pending,
    // and marks it settled (success/error) in the Timeline.
    final mutation = MutationController<User, String, void>(
      mutator: (name) => ApiService.updateUser(1, name),
      options: MutationOptions(
        onSuccess: (user, _, __) async {
          widget.client.invalidate(const ['users']);
        },
      ),
    );

    final updated = await mutation.mutate(_controller.text);
    mutation.dispose();

    if (mounted) {
      setState(() {
        _pending = false;
        _result = updated != null ? 'Saved: ${updated.name}' : 'Failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update user')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_result!,
                    style: const TextStyle(color: Colors.green)),
              ),
            FilledButton(
              onPressed: _pending ? null : _save,
              child: _pending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Example 3 — Optimistic update: appears in Timeline as "Optimistic Update"
// ---------------------------------------------------------------------------

class OptimisticScreen extends StatefulWidget {
  const OptimisticScreen({super.key, required this.client});

  final QoraClient client;

  @override
  State<OptimisticScreen> createState() => _OptimisticScreenState();
}

class _OptimisticScreenState extends State<OptimisticScreen> {
  String _status = 'idle';

  Future<void> _runOptimistic() async {
    setState(() => _status = 'applying optimistic...');

    // 1. Capture the current cache snapshot for rollback.
    final snapshot = widget.client.getQueryData<User>(const ['users', 1]);

    // 2. Write the optimistic value — triggers onOptimisticUpdate in tracker.
    widget.client.setQueryData<User>(
      const ['users', 1],
      const User(id: 1, name: 'Optimistic Alice', email: 'alice@x.com'),
    );

    try {
      // 3. Perform the real network call.
      await ApiService.updateUser(1, 'Alice');
      widget.client.invalidate(const ['users', 1]);
      setState(() => _status = 'confirmed ✓');
    } catch (_) {
      // 4. Rollback on failure — snapshot restores the pre-optimistic state.
      widget.client.restoreQueryData(const ['users', 1], snapshot);
      setState(() => _status = 'rolled back ✗');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Optimistic update')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _runOptimistic,
              child: const Text('Run optimistic update'),
            ),
            const SizedBox(height: 8),
            Text(
              'Open the Qora overlay (FAB ▶ button) and check the '
              'Timeline tab to see the "Optimistic Update" event.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fake models and API
// ---------------------------------------------------------------------------

class User {
  final int id;
  final String name;
  final String email;

  const User({required this.id, required this.name, required this.email});
}

abstract class ApiService {
  static Future<List<User>> getUsers() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List.generate(
      8,
      (i) => User(id: i + 1, name: 'User ${i + 1}', email: 'u${i + 1}@x.com'),
    );
  }

  static Future<User> updateUser(int id, String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return User(id: id, name: name, email: 'u$id@x.com');
  }
}
