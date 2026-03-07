import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/mutation/mutation_inspector.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/query/query_inspector.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

/// Dispatches to [QueryInspector] or [MutationInspector] based on [showQuery].
///
/// Renders a sticky header that shows "QUERY INSPECTOR" or "MUTATION INSPECTOR"
/// and animates between the two inspectors when [showQuery] changes.
class InspectorPanel extends StatelessWidget {
  /// When `true`, renders [QueryInspector]; otherwise renders [MutationInspector].
  final bool showQuery;

  const InspectorPanel({super.key, required this.showQuery});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        _InspectorHeader(showQuery: showQuery),

        // ── Content ────────────────────────────────────────────────────────
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: showQuery
                ? const QueryInspector(key: ValueKey('query'))
                : const MutationInspector(key: ValueKey('mutation')),
          ),
        ),
      ],
    );
  }
}

class _InspectorHeader extends StatelessWidget {
  final bool showQuery;
  const _InspectorHeader({required this.showQuery});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DevtoolsColors.border)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        showQuery ? 'INSPECTOR' : 'MUTATION INSPECTOR',
        key: ValueKey(showQuery),
        style: DevtoolsTypography.tab.copyWith(letterSpacing: 0.6),
      ),
    );
  }
}
