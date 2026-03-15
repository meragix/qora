import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/query_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/inspector_widgets.dart';
import 'package:qora_devtools_overlay/src/ui/shared/empty_state.dart';
import 'package:qora_devtools_overlay/src/ui/shared/json_viewer.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Inspector detail view for a selected query.
///
/// Two tabs (memorised across selections):
/// - OVERVIEW: QUERY KEY + ACTIONS + METADATA
/// - DATA: CACHED DATA
class QueryInspector extends StatefulWidget {
  const QueryInspector({super.key});

  @override
  State<QueryInspector> createState() => _QueryInspectorState();
}

class _QueryInspectorState extends State<QueryInspector>
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
    final notifier = context.watch<QueryInspectorNotifier>();
    final detail = notifier.detail;

    if (detail == null) {
      return const EmptyState(message: 'Select a query to inspect');
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
                padding: 12.edgeInsetsA,
                children: [
                  // QUERY KEY
                  InspectorSection(
                    label: 'QUERY KEY',
                    child: Container(
                      padding: [8, 10].edgeInsetsVH,
                      decoration: BoxDecoration(
                        color: DevtoolsColors.panelSecondaryBackground,
                        borderRadius: 4.borderRadiusA,
                      ),
                      child: Text(
                        detail.key.fmtKey(),
                        style: DevtoolsTypography.code,
                      ),
                    ),
                  ),

                  // ACTIONS
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
                            accentColor: const Color(0xFF4F46E5),
                            onTap: notifier.refetch,
                          ),
                          InspectorActionButton(
                            label: 'Invalidate',
                            icon: LucideIcons.circleAlert,
                            accentColor: DevtoolsColors.zinc700,
                            onTap: notifier.invalidate,
                          ),
                          InspectorActionButton(
                            label: 'Remove',
                            icon: LucideIcons.trash2,
                            accentColor: const Color(0xFFB91C1C),
                            onTap: notifier.remove,
                          ),
                          InspectorActionButton(
                            label: 'Mark Stale',
                            icon: LucideIcons.clockArrowDown,
                            accentColor: const Color(0xFFB45309),
                            onTap: notifier.markStale,
                          ),
                          InspectorActionButton(
                            label: 'Simulate Error',
                            icon: LucideIcons.circleX,
                            accentColor: const Color(0xFFC2410C),
                            onTap: notifier.simulateError,
                          ),
                        ],
                      ),
                    ),

                  // METADATA
                  InspectorSection(
                    label: 'METADATA',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (detail.createdAt != null)
                          InspectorMetaRow(
                              'Created At:', detail.createdAt!.fmtDateTime()),
                        InspectorMetaRow(
                            'Updated At:', detail.updatedAt.fmtDateTime()),
                        if (detail.staleAt != null)
                          InspectorMetaRow(
                              'Stale At:', detail.staleAt!.fmtDateTime()),
                        if (detail.cacheTimeMs != null)
                          InspectorMetaRow(
                            'Cache Time:',
                            '${(detail.cacheTimeMs! / 1000).round()}s',
                          ),
                        if (detail.fetchDurationMs != null)
                          InspectorMetaRow(
                              'Fetch Duration:', '${detail.fetchDurationMs}ms'),
                        if (detail.retryCount != null)
                          InspectorMetaRow(
                              'Retry Count:', '${detail.retryCount}'),
                      ],
                    ),
                  ),

                  // STATE MACHINE
                  InspectorSection(
                    label: 'STATE MACHINE',
                    showDivider: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(builder: (context) {
                          final isFetching = detail.status == 'loading';
                          final isStale = (detail.staleAt != null &&
                                  DateTime.now().isAfter(detail.staleAt!)) ||
                              detail.status == 'stale';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InspectorMetaRow(
                                'Is Fetching:',
                                isFetching ? 'true' : 'false',
                                valueColor: isFetching
                                    ? DevtoolsColors.blue400
                                    : DevtoolsColors.textDisabled,
                              ),
                              InspectorMetaRow(
                                'Is Invalidated:',
                                detail.isInvalidated ? 'true' : 'false',
                                valueColor: detail.isInvalidated
                                    ? DevtoolsColors.highlight
                                    : DevtoolsColors.textDisabled,
                              ),
                              InspectorMetaRow(
                                'Is Stale:',
                                isStale ? 'true' : 'false',
                                valueColor: isStale
                                    ? DevtoolsColors.statusStale
                                    : DevtoolsColors.textDisabled,
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),

              // ── DATA ──────────────────────────────────────────────────────
              ListView(
                padding: 12.edgeInsetsA,
                children: [
                  InspectorSection(
                    label: 'CACHED DATA',
                    showDivider: false,
                    child: detail.hasLargePayload
                        ? Text(
                            'Large payload — pull via DevTools extension',
                            style: DevtoolsTypography.smallMuted,
                          )
                        : Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .3),
                              borderRadius: 8.borderRadiusA,
                            ),
                            child: Padding(
                              padding: 12.edgeInsetsA,
                              child: JsonViewer(
                                key: ValueKey(detail.key),
                                data: detail.data,
                              ),
                            ),
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
