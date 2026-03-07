import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/mutation/mutation_inspector.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/query/query_inspector.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';

/// Dispatches to [QueryInspector] or [MutationInspector] based on [showQuery].
///
/// [PanelBody] sets [showQuery] to `true` when the user taps a query row and
/// `false` when they tap a mutation row, keeping the inspector in sync with the
/// list panel's active tab.
class InspectorPanel extends StatelessWidget {
  /// When `true`, renders [QueryInspector]; otherwise renders [MutationInspector].
  final bool showQuery;

  const InspectorPanel({super.key, required this.showQuery});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: showQuery
          ? const QueryInspector(key: ValueKey('query'))
          : const MutationInspector(key: ValueKey('mutation')),
    );
  }
}

/// Shown when no query or mutation has been selected yet.
class InspectorEmpty extends StatelessWidget {
  const InspectorEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Select a query or mutation',
        style: TextStyle(color: DevtoolsColors.textMuted, fontSize: 13),
      ),
    );
  }
}
