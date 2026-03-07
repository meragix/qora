import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/query_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/inspector_widgets.dart';
import 'package:qora_devtools_overlay/src/ui/shared/expandable_object.dart';
import 'package:qora_devtools_overlay/src/ui/shared/status_badge.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

/// Inspector detail view for a selected query.
///
/// Reads [QueryInspectorNotifier] and renders STATUS / CACHED DATA / METADATA
/// sections derived from the most recently selected [QueryEvent].
class QueryInspector extends StatelessWidget {
  const QueryInspector({super.key});

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<QueryInspectorNotifier>().detail;

    if (detail == null) {
      return const Center(
        child: Text(
          'Select a query to inspect',
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

        // ── CACHED DATA ─────────────────────────────────────────────────────
        InspectorSection(
          label: 'CACHED DATA',
          child: detail.hasLargePayload
              ? Text(
                  'Large payload — pull via DevTools extension',
                  style: DevtoolsTypography.smallMuted,
                )
              : ExpandableObject(
                  label: detail.dataPreview != null ? 'Object' : 'null',
                  preview: detail.dataPreview,
                ),
        ),

        // ── METADATA ────────────────────────────────────────────────────────
        InspectorSection(
          label: 'METADATA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InspectorMetaRow('Fetched At', fmtDateTime(detail.fetchedAt)),
              if (detail.fetchDurationMs != null)
                InspectorMetaRow('Duration', '${detail.fetchDurationMs} ms'),
              InspectorMetaRow(
                'Large Payload',
                detail.hasLargePayload ? 'yes' : 'no',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
