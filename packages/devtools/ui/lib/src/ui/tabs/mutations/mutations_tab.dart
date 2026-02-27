import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/state/timeline_controller.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col1_mutations_list/mutations_list.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col2_mutation_inspector/mutation_inspector.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col3_secondary_tabs/timeline/timeline_tab.dart';

/// Main MUTATIONS tab laid out in three columns.
class MutationsTab extends StatelessWidget {
  /// Creates a mutations tab.
  const MutationsTab({
    super.key,
    required this.timelineController,
    required this.fallbackTimeline,
  });

  /// Shared timeline controller.
  final TimelineController timelineController;

  /// Fallback widget for timeline rendering.
  final Widget fallbackTimeline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(flex: 3, child: MutationsList()),
        const VerticalDivider(width: 1),
        const Expanded(flex: 4, child: MutationInspector()),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 5,
          child: TimelineTab(
            controller: timelineController,
            fallback: fallbackTimeline,
          ),
        ),
      ],
    );
  }
}
