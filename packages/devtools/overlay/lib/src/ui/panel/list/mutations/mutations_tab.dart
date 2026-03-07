import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutations_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/mutations/mutation_row.dart';
import 'package:qora_devtools_overlay/src/ui/shared/empty_state.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class MutationsTab extends StatelessWidget {
  final void Function(MutationEvent) onMutationTap;

  const MutationsTab({super.key, required this.onMutationTap});

  @override
  Widget build(BuildContext context) {
    final mutations = context.watch<MutationsNotifier>().mutations.reversed.toList();

    if (mutations.isEmpty) {
      return const EmptyState(message: 'No mutations yet');
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
