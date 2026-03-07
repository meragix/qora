import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/inspector_widgets.dart';
import 'package:qora_devtools_overlay/src/ui/shared/json_viewer.dart';
import 'package:qora_devtools_overlay/src/ui/shared/status_badge.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

/// Inspector detail view for a selected mutation.
///
/// Two tabs (memorised across selections):
/// - OVERVIEW: STATUS + ACTIONS + METADATA
/// - DATA: VARIABLES + ERROR + ROLLBACK CONTEXT
class MutationInspector extends StatefulWidget {
  const MutationInspector({super.key});

  @override
  State<MutationInspector> createState() => _MutationInspectorState();
}

class _MutationInspectorState extends State<MutationInspector>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MutationInspectorNotifier>();
    final detail = notifier.detail;

    if (detail == null) {
      return const Center(
        child: Text(
          'Select a mutation to inspect',
          style: TextStyle(color: DevtoolsColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        // ── Tab bar ─────────────────────────────────────────────────────────
        SizedBox(
         height: DevtoolsSpacing.tabHeight,
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [Tab(text: 'OVERVIEW'), Tab(text: 'DATA')],
            labelStyle: DevtoolsTypography.tab,
          ),
        ),

        // ── Tab content ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ── OVERVIEW ──────────────────────────────────────────────────
              ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // STATUS
                  InspectorSection(
                    label: 'STATUS',
                    child: StatusBadge(status: detail.status),
                  ),

                  // ACTIONS
                  if (detail.status == 'error')
                    InspectorSection(
                      label: 'ACTIONS',
                      child: InspectorActionButton(
                        label: 'Retry',
                        icon: Icons.refresh_rounded,
                        onTap: () => notifier.retry(),
                      ),
                    ),

                  // METADATA
                  InspectorSection(
                    label: 'METADATA',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InspectorMetaRow(
                            'Created At', fmtDateTime(detail.createdAt)),
                        if (detail.submittedAt != null)
                          InspectorMetaRow(
                              'Submitted At', fmtDateTime(detail.submittedAt!)),
                        if (detail.updatedAt != null)
                          InspectorMetaRow(
                              'Updated At', fmtDateTime(detail.updatedAt!)),
                        InspectorMetaRow('Retry Count', '${detail.retryCount}'),
                      ],
                    ),
                  ),
                ],
              ),

              // ── DATA ──────────────────────────────────────────────────────
              ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // VARIABLES
                  InspectorSection(
                    label: 'VARIABLES',
                    child: JsonViewer(data: detail.variables),
                  ),

                  // ERROR — conditional
                  if (detail.error != null)
                    InspectorSection(
                      label: 'ERROR',
                      child: JsonViewer(data: detail.error),
                    ),

                  // ROLLBACK CONTEXT — optimistic updates only
                  if (detail.rollbackContext != null)
                    InspectorSection(
                      label: 'ROLLBACK CONTEXT',
                      child: JsonViewer(data: detail.rollbackContext),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
