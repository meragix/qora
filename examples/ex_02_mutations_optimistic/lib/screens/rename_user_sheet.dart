import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

import '../models/user.dart';
import '../services/fake_api.dart';

// Snapshot type carried as TContext through the mutation lifecycle.
typedef _Snapshot = ({User? user, List<User>? list});

// Variable type passed to the mutator.
typedef _UpdateVars = ({String id, String name});

/// Bottom sheet for renaming a user with an optimistic cache update.
///
/// Demonstrates the three-step optimistic update protocol:
///
/// 1. [MutationOptions.onMutate]  — snapshot current cache + apply
///    [QoraClient.setQueryData] immediately (before server confirmation).
/// 2. [MutationOptions.onError]   — [QoraClient.restoreQueryData] restores
///    both cache entries to the pre-mutation snapshot on server failure.
/// 3. [MutationOptions.onSuccess] — [QoraClient.invalidateWhere] triggers
///    a background refetch to reconcile the cache with the server state.
class RenameUserSheet extends StatefulWidget {
  final User user;

  /// Direct reference to [QoraClient].
  ///
  /// Passed explicitly because modal routes run in a separate navigator overlay
  /// that may not resolve [QoraScope] through the widget tree. Capturing the
  /// client from the calling screen's [BuildContext] before opening the sheet
  /// ensures the callbacks operate on the correct client instance.
  final QoraClient client;

  const RenameUserSheet({
    super.key,
    required this.user,
    required this.client,
  });

  @override
  State<RenameUserSheet> createState() => _RenameUserSheetState();
}

class _RenameUserSheetState extends State<RenameUserSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;

    return QoraMutationBuilder<User, _UpdateVars, _Snapshot>(
      mutator: (vars) => FakeApi.updateUser(vars.id, name: vars.name),
      options: MutationOptions<User, _UpdateVars, _Snapshot>(
        // ── Step 1: snapshot + optimistic cache update ───────────────────────
        onMutate: (vars) async {
          // Capture the current data for both cache entries before mutating.
          final prevUser = client.getQueryData<User>(['users', vars.id]);
          final prevList = client.getQueryData<List<User>>(['users']);

          // Apply the optimistic name change to the per-user detail cache.
          if (prevUser != null) {
            client.setQueryData<User>(
              ['users', vars.id],
              prevUser.copyWith(name: vars.name),
            );
          }

          // Apply the same change to the matching entry inside the list cache.
          if (prevList != null) {
            client.setQueryData<List<User>>(
              ['users'],
              prevList
                  .map((u) => u.id == vars.id ? u.copyWith(name: vars.name) : u)
                  .toList(),
            );
          }

          // Return both snapshots as the rollback context (TContext).
          return (user: prevUser, list: prevList);
        },

        // ── Step 2: rollback on server error ─────────────────────────────────
        onError: (error, vars, ctx) async {
          // Restore both cache entries from the snapshot returned by onMutate.
          client.restoreQueryData<User>(['users', vars.id], ctx?.user);
          client.restoreQueryData<List<User>>(['users'], ctx?.list);
        },

        // ── Step 3: server reconciliation on success ──────────────────────────
        onSuccess: (user, vars, _) async {
          // Trigger a background refetch for all user-related entries
          // so the cache reflects the server-confirmed state.
          client.invalidateWhere((key) => key.firstOrNull == 'users');
        },
      ),
      builder: (context, state, mutate) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rename ${widget.user.avatar} ${widget.user.name}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name input
              TextField(
                controller: _nameController,
                enabled: !state.isPending,
                decoration: const InputDecoration(
                  labelText: 'New name',
                  border: OutlineInputBorder(),
                  helperText: 'The list updates immediately — server confirms in ~2 s',
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(state, mutate),
              ),
              const SizedBox(height: 12),

              // Inline status feedback
              switch (state) {
                MutationFailure(:final error) => _FeedbackBanner(
                    icon: Icons.undo_rounded,
                    message: 'Save failed — name restored. $error',
                    color: Colors.red,
                  ),
                MutationSuccess() => const _FeedbackBanner(
                    icon: Icons.check_circle_outline,
                    message: 'Saved. Cache updated from server.',
                    color: Colors.green,
                  ),
                _ => const SizedBox.shrink(),
              },

              const SizedBox(height: 12),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: state.isPending ? null : () => _submit(state, mutate),
                      child: state.isPending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit(
    MutationState<User, _UpdateVars> state,
    Future<User?> Function(_UpdateVars) mutate,
  ) {
    if (state.isPending) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    mutate((id: widget.user.id, name: name));
  }
}

class _FeedbackBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final MaterialColor color;

  const _FeedbackBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: color.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
