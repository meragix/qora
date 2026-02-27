import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col1_mutations_list/mutation_list_item.dart';

/// Left column showing the list of tracked mutations.
class MutationsList extends StatelessWidget {
  /// Creates the mutations list column.
  const MutationsList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const <Widget>[
        Text('MUTATIONS (0)', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        MutationListItem(title: 'No mutation data yet'),
      ],
    );
  }
}
