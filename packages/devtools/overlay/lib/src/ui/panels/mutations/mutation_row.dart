import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutations_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panels/shared/breadcrumb_key.dart';
import 'package:qora_devtools_overlay/src/ui/panels/shared/status_badge.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Single row in the Mutations list column (column 1).
///
/// Shows the [BreadcrumbKey] for [MutationEvent.key] and a [StatusBadge]
/// derived from [MutationEvent.type] and [MutationEvent.success].
class MutationRow extends StatelessWidget {
  final MutationEvent mutation;
  final VoidCallback onTap;

  const MutationRow({super.key, required this.mutation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BreadcrumbKey(queryKey: mutation.key),
                  const SizedBox(height: 2),
                  Text(
                    mutation.id,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: _statusFrom(mutation)),
          ],
        ),
      ),
    );
  }

  String _statusFrom(MutationEvent e) {
    if (e.type == MutationEventType.settled) {
      return (e.success ?? false) ? 'success' : 'error';
    }
    return 'pending';
  }
}

/// Column 1 of the Mutations panel — scrollable list of all observed mutations.
///
/// Reads [MutationsNotifier] and delegates tap handling to [onMutationTap].
class MutationListColumn extends StatelessWidget {
  final void Function(MutationEvent) onMutationTap;

  const MutationListColumn({super.key, required this.onMutationTap});

  @override
  Widget build(BuildContext context) {
    final mutations =
        context.watch<MutationsNotifier>().mutations.reversed.toList();

    if (mutations.isEmpty) {
      return const Center(
        child: Text(
          'No mutations yet',
          style: TextStyle(color: Color(0xFF475569), fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: mutations.length,
      itemBuilder: (context, i) => MutationRow(
        mutation: mutations[i],
        onTap: () => onMutationTap(mutations[i]),
      ),
    );
  }
}
