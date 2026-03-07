import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/domain/mutations_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/mutations/mutation_row.dart';
import 'package:qora_devtools_overlay/src/ui/shared/empty_state.dart';
import 'package:qora_devtools_overlay/src/ui/shared/panel_section.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class MutationsTab extends StatelessWidget {
  final void Function(MutationEvent) onMutationTap;

  const MutationsTab({super.key, required this.onMutationTap});

  @override
  Widget build(BuildContext context) {
    final mutations = context.watch<MutationsNotifier>().mutations.reversed.toList();
    // Drive active highlight from the notifier so it survives tab switches.
    final selectedId = context.watch<MutationInspectorNotifier>().selected?.id;

    if (mutations.isEmpty) {
      return const EmptyState(message: 'No mutations yet');
    }

    return Column(
      children: [
        PanelSection(label: 'MUTATIONS (${mutations.length})'),
        Expanded(
          child: ListView.builder(
            itemCount: mutations.length,
            itemBuilder: (_, i) => Column(
              children: [
                Divider(height: DevtoolsSpacing.borderWidth),
                MutationRow(
                  mutation: mutations[i],
                  isActive: selectedId == mutations[i].id,
                  onTap: () => onMutationTap(mutations[i]),
                ),
                if (i == mutations.length - 1) Divider(height: DevtoolsSpacing.borderWidth),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
