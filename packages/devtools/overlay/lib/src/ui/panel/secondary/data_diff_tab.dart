import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/shared/json_viewer.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Data Diff tab — column 3, third tab of the Mutations panel.
///
/// Shows a before/after comparison for the selected mutation:
/// - **Before** — variables submitted to the mutator
/// - **After**  — result returned from the server (or error on failure)
///
/// When a rollback context is present (optimistic update), it is shown in the
/// before column, indicating the pre-optimistic cache snapshot.
class DataDiffTab extends StatelessWidget {
  const DataDiffTab({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MutationInspectorNotifier>();
    final selected = notifier.selected;

    if (selected == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.fileDiff, color: DevtoolsColors.textMuted, size: 32),
            SizedBox(height: 8),
            Text(
              'Select a mutation to compare data',
              style: TextStyle(color: DevtoolsColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final isSettled = selected.type == MutationEventType.settled;
    final isSuccess = isSettled && (selected.success ?? false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Before column ───────────────────────────────────────────────────
        Expanded(
          child: _DiffColumn(
            key: ValueKey('${selected.id}_before'),
            label: 'BEFORE',
            labelColor: const Color(0xFF64748B),
            value: selected.variables,
            emptyText: 'No variables sent',
          ),
        ),
        const VerticalDivider(width: 1, color: Color(0xFF1E293B)),
        // ── After column ────────────────────────────────────────────────────
        Expanded(
          child: _DiffColumn(
            key: ValueKey('${selected.id}_after'),
            label: isSettled
                ? (isSuccess ? 'AFTER (success)' : 'AFTER (error)')
                : 'AFTER (pending)',
            labelColor: isSettled
                ? (isSuccess
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444))
                : const Color(0xFF64748B),
            value: selected.result,
            emptyText: isSettled ? 'No result data' : 'Pending…',
          ),
        ),
      ],
    );
  }
}

// ── Diff column ───────────────────────────────────────────────────────────────

class _DiffColumn extends StatelessWidget {
  const _DiffColumn({
    super.key,
    required this.label,
    required this.labelColor,
    required this.value,
    required this.emptyText,
  });

  final String label;
  final Color labelColor;
  final Object? value;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: labelColor.withValues(alpha: 0.1),
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: value != null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: JsonViewer(data: value),
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    emptyText,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
