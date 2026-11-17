import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/inspector_widgets.dart';
import 'package:qora_devtools_overlay/src/ui/shared/json_viewer.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/shared/status_badge.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Inspector detail view for a selected mutation.
///
/// Two tabs (memorised across selections):
/// - OVERVIEW: key, status and timestamps
/// - DETAILS: variables, then the result or the error
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
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.tab,
            padding: 12.edgeInsetsH,
            labelPadding: 12.edgeInsetsH,
            tabAlignment: TabAlignment.start,
            tabs: const [Tab(text: 'OVERVIEW'), Tab(text: 'DETAILS')],
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
                  // MUTATION KEY
                  if (detail.key != null && detail.key!.isNotEmpty)
                    InspectorSection(
                      label: 'MUTATION KEY',
                      child: Container(
                        padding: [8, 10].edgeInsetsVH,
                        decoration: BoxDecoration(
                          color: DevtoolsColors.panelSecondaryBackground,
                          borderRadius: 4.borderRadiusA,
                        ),
                        child: Text(
                          detail.key!.fmtKey(),
                          style: DevtoolsTypography.code,
                        ),
                      ),
                    ),
                  // STATUS
                  InspectorSection(
                    label: 'STATUS',
                    child: StatusBadge(status: detail.status),
                  ),

                  // METADATA
                  InspectorSection(
                    label: 'METADATA',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InspectorMetaRow(
                            'Created At', detail.createdAt.fmtDateTime()),
                        if (detail.updatedAt != null)
                          InspectorMetaRow(
                              'Updated At', detail.updatedAt!.fmtDateTime()),
                        if (detail.elapsedMs != null)
                          InspectorMetaRow('Duration', '${detail.elapsedMs}ms'),
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
                    child: JsonViewer(
                      key: ValueKey('${detail.id}_vars'),
                      data: detail.variables,
                    ),
                  ),

                  // DATA: server response on success
                  if (detail.data != null)
                    InspectorSection(
                      label: 'DATA',
                      child: JsonViewer(
                        key: ValueKey('${detail.id}_data'),
                        data: detail.data,
                      ),
                    ),

                  // ERROR: on failure
                  if (detail.error != null)
                    InspectorSection(
                      label: 'ERROR',
                      child: JsonViewer(
                        key: ValueKey('${detail.id}_error'),
                        data: detail.error,
                      ),
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
