import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/inspector_widgets.dart';
import 'package:qora_devtools_overlay/src/ui/shared/expandable_object.dart';
import 'package:qora_devtools_overlay/src/ui/shared/status_badge.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';

/// Inspector detail view for a selected mutation.
///
/// Reads [MutationInspectorNotifier] and renders STATUS / ACTIONS / VARIABLES /
/// ERROR / ROLLBACK CONTEXT / METADATA sections for the selected [MutationEvent].
class MutationInspector extends StatelessWidget {
  const MutationInspector({super.key});

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<MutationInspectorNotifier>().detail;

    if (detail == null) {
      return const Center(
        child: Text(
          'Select a mutation to inspect',
          style: TextStyle(color: DevtoolsColors.textMuted, fontSize: 13),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── STATUS ──────────────────────────────────────────────────────────
        InspectorSection(
          label: 'STATUS',
          child: StatusBadge(status: detail.status),
        ),

        // ── ACTIONS ─────────────────────────────────────────────────────────
        if (detail.status == 'error')
          InspectorSection(
            label: 'ACTIONS',
            child: InspectorActionButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onTap: () => context.read<MutationInspectorNotifier>().retry(),
            ),
          ),

        // ── VARIABLES ───────────────────────────────────────────────────────
        InspectorSection(
          label: 'VARIABLES',
          child: ExpandableObject(
            label: 'Object(${detail.variablesCount})',
            preview: detail.variablesPreview,
          ),
        ),

        // ── ERROR — conditional ─────────────────────────────────────────────
        if (detail.errorPreview != null)
          InspectorSection(
            label: 'ERROR',
            child: ExpandableObject(
              label: 'Object(${detail.errorCount})',
              preview: detail.errorPreview,
              isError: true,
            ),
          ),

        // ── ROLLBACK CONTEXT — optimistic updates only ──────────────────────
        if (detail.rollbackContextPreview != null)
          InspectorSection(
            label: 'ROLLBACK CONTEXT',
            child: ExpandableObject(
              label: 'Object(${detail.rollbackCount})',
              preview: detail.rollbackContextPreview,
            ),
          ),

        // ── METADATA ────────────────────────────────────────────────────────
        InspectorSection(
          label: 'METADATA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InspectorMetaRow('Created At', fmtDateTime(detail.createdAt)),
              if (detail.submittedAt != null)
                InspectorMetaRow('Submitted At', fmtDateTime(detail.submittedAt!)),
              if (detail.updatedAt != null)
                InspectorMetaRow('Updated At', fmtDateTime(detail.updatedAt!)),
              InspectorMetaRow('Retry Count', '${detail.retryCount}'),
            ],
          ),
        ),
      ],
    );
  }
}
