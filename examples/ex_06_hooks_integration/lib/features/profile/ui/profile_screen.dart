import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_flutter/qora_flutter.dart';
import 'package:qora_hooks/qora_hooks.dart';

import '../../../shared/api/json_placeholder_api.dart';
import '../models/user.dart';

/// Profile screen demonstrating [useQuery] + [useMutation] composition.
///
/// Both hooks are declared at the top of [build] — no nested builders,
/// no custom [State], no [StreamSubscription].
///
/// | Hook              | Purpose                                          |
/// |-------------------|--------------------------------------------------|
/// | `useQueryClient`  | Imperative invalidation after a successful save  |
/// | `useQuery`        | Fetch + subscribe to `['users', userId]`         |
/// | `useMutation`     | PUT the updated name; show pending / error state |
class ProfileScreen extends HookWidget {
  final String userId;
  final JsonPlaceholderApi api;

  const ProfileScreen({super.key, required this.userId, required this.api});

  @override
  Widget build(BuildContext context) {
    // ── Hooks ─────────────────────────────────────────────────────────────
    final client = useQueryClient();

    final userQuery = useQuery<User>(
      key: ['users', userId],
      fetcher: () => api.getUser(userId),
      options: const QoraOptions(staleTime: Duration(minutes: 5)),
    );

    final updateMutation = useMutation<User, UpdateUserInput>(
      mutator: api.updateUser,
      options: MutationOptions(
        onSuccess: (_, _, _) async =>
            client.invalidate(['users', userId]),
      ),
    );

    // ── UI ────────────────────────────────────────────────────────────────
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (updateMutation.isError)
            IconButton(
              icon: Icon(Icons.warning_amber, color: Colors.orange.shade700),
              tooltip: 'Save failed — tap to reset',
              onPressed: updateMutation.reset,
            ),
        ],
      ),
      body: switch (userQuery) {
        Initial() || Loading(previousData: null) =>
          const Center(child: CircularProgressIndicator()),
        Failure(:final error, previousData: null) =>
          _ErrorView(error: error, onRetry: () => client.invalidate(['users', userId])),
        _ => _ProfileBody(
            user: userQuery.dataOrNull!,
            isSaving: updateMutation.isPending,
            saveError: updateMutation.error,
            onSave: (name, username) => updateMutation.mutate(
              UpdateUserInput(id: userId, name: name, username: username),
            ),
          ),
      },
    );
  }
}

// ── Profile form ──────────────────────────────────────────────────────────────

class _ProfileBody extends StatefulWidget {
  final User user;
  final bool isSaving;
  final Object? saveError;
  final void Function(String name, String username) onSave;

  const _ProfileBody({
    required this.user,
    required this.isSaving,
    required this.saveError,
    required this.onSave,
  });

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _usernameCtrl = TextEditingController(text: widget.user.username);
  }

  @override
  void didUpdateWidget(_ProfileBody old) {
    super.didUpdateWidget(old);
    // Sync fields if the server data changes (e.g., after invalidation).
    if (old.user != widget.user) {
      _nameCtrl.text = widget.user.name;
      _usernameCtrl.text = widget.user.username;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Avatar
        Center(
          child: CircleAvatar(
            radius: 40,
            child: Text(
              widget.user.name[0].toUpperCase(),
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            widget.user.email,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 32),

        // Form
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Display name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _usernameCtrl,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixText: '@',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),

        // Save error
        if (widget.saveError != null) ...[
          Text(
            'Save failed: ${widget.saveError}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
        ],

        // Save button
        FilledButton(
          onPressed: widget.isSaving
              ? null
              : () => widget.onSave(_nameCtrl.text, _usernameCtrl.text),
          child: widget.isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save changes'),
        ),

        // JSONPlaceholder note
        const SizedBox(height: 16),
        Text(
          'Note: JSONPlaceholder is a fake API — saves are reflected locally '
          'but not persisted on the server.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
