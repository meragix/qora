import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/shared/empty_state.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col2_mutation_inspector/expandable_object.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col2_mutation_inspector/inspector_section.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col2_mutation_inspector/metadata_table.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col2_mutation_inspector/retry_button.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col2_mutation_inspector/status_badge.dart';

/// Middle column inspector for a selected mutation.
class MutationInspector extends StatelessWidget {
  /// Creates mutation inspector.
  const MutationInspector({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const <Widget>[
        InspectorSection(title: 'STATUS', child: StatusBadge(label: 'idle')),
        SizedBox(height: 12),
        InspectorSection(title: 'ACTIONS', child: RetryButton()),
        SizedBox(height: 12),
        InspectorSection(
            title: 'VARIABLES', child: ExpandableObject(label: 'Object(0)')),
        SizedBox(height: 12),
        InspectorSection(
            title: 'ERROR', child: EmptyState(message: 'No error')),
        SizedBox(height: 12),
        InspectorSection(
            title: 'ROLLBACK CONTEXT',
            child: ExpandableObject(label: 'Object(0)')),
        SizedBox(height: 12),
        InspectorSection(title: 'METADATA', child: MetadataTable()),
      ],
    );
  }
}
