import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora/qora.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_queue_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/queue/queue_row.dart';
import 'package:qora_devtools_overlay/src/ui/shared/empty_state.dart';
import 'package:qora_devtools_overlay/src/ui/shared/panel_section.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';

/// The calls waiting in [QoraClient.mutationQueue], in the order they were
/// made. Read only: retrying or discarding stays the app's decision.
class QueueTab extends StatelessWidget {
  const QueueTab({super.key, required this.onEntryTap});

  final void Function(QueuedMutation) onEntryTap;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MutationQueueNotifier>();

    if (!notifier.isAvailable) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyState(
          message: 'Pass client: to QoraInspector to see the mutation queue.',
        ),
      );
    }

    final entries = notifier.entries;
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyState(
          message: 'The mutation queue is empty. Calls to a registered '
              'mutation with offlineQueue: true wait here until they are '
              'sent.',
        ),
      );
    }

    return Column(
      children: [
        PanelSection(label: 'QUEUE (${entries.length})'),
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                Divider(height: DevtoolsSpacing.borderWidth),
            itemBuilder: (_, i) => QueueRow(
              entry: entries[i],
              isSelected: notifier.selectedId == entries[i].mutationId,
              onTap: () => onEntryTap(entries[i]),
            ),
          ),
        ),
      ],
    );
  }
}
