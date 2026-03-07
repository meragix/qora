import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/query_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/inspector_widgets.dart';
import 'package:qora_devtools_overlay/src/ui/shared/expandable_object.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

/// Inspector detail view for a selected query.
///
/// Sections: QUERY KEY → ACTIONS → CACHED DATA → METADATA
class QueryInspector extends StatelessWidget {
  const QueryInspector({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<QueryInspectorNotifier>();
    final detail = notifier.detail;

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
        // ── QUERY KEY ───────────────────────────────────────────────────────
        InspectorSection(
          label: 'QUERY KEY',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: DevtoolsColors.panelSecondaryBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatKey(detail.key),
              style: DevtoolsTypography.code,
            ),
          ),
        ),

        // ── ACTIONS ─────────────────────────────────────────────────────────
        if (notifier.hasClient)
          InspectorSection(
            label: 'ACTIONS',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                InspectorActionButton(
                  label: 'Refetch',
                  icon: LucideIcons.refreshCw,
                  accentColor: DevtoolsColors.accent,
                  onTap: notifier.refetch,
                ),
                InspectorActionButton(
                  label: 'Invalidate',
                  icon: LucideIcons.circleAlert,
                  accentColor: const Color(0xFFF97316),
                  onTap: notifier.invalidate,
                ),
                InspectorActionButton(
                  label: 'Remove',
                  icon: LucideIcons.trash2,
                  accentColor: DevtoolsColors.statusError,
                  onTap: notifier.remove,
                ),
                InspectorActionButton(
                  label: 'Mark Stale',
                  icon: LucideIcons.clockArrowDown,
                  accentColor: DevtoolsColors.statusStale,
                  onTap: notifier.markStale,
                ),
                InspectorActionButton(
                  label: 'Simulate Error',
                  icon: LucideIcons.circleX,
                  accentColor: DevtoolsColors.statusError,
                  onTap: notifier.simulateError,
                ),
              ],
            ),
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
                  label: detail.data != null ? 'Object' : 'null',
                  preview: detail.dataPreview,
                ),
        ),

        // ── METADATA ────────────────────────────────────────────────────────
        InspectorSection(
          label: 'METADATA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InspectorMetaRow('Updated At', fmtDateTime(detail.updatedAt)),
              if (detail.staleAt != null)
                InspectorMetaRow('Stale At', fmtDateTime(detail.staleAt!)),
              if (detail.cacheTimeMs != null)
                InspectorMetaRow(
                  'Cache Time',
                  '${(detail.cacheTimeMs! / 1000).round()}s',
                ),
              InspectorMetaRow('Observers', '${detail.observerCount}'),
              if (detail.fetchDurationMs != null)
                InspectorMetaRow('Fetch Duration', '${detail.fetchDurationMs}ms'),
            ],
          ),
        ),
      ],
    );
  }

  /// Formats the serialised key into a readable `[ "user", "42" ]` form.
  String _formatKey(String key) {
    try {
      // Already JSON — pretty-print with bracket spacing.
      return key
          .replaceAll(',', ', ')
          .replaceAll('[', '[ ')
          .replaceAll(']', ' ]');
    } catch (_) {
      return key;
    }
  }
}
