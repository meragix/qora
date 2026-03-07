import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/queries/queries_tab.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/mutations/mutations_tab.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class LeftPanel extends StatelessWidget {
  final void Function(QueryEvent) onQueryTap;
  final void Function(MutationEvent) onMutationTap;

  const LeftPanel({
    super.key,
    required this.onQueryTap,
    required this.onMutationTap,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          SizedBox(
            height: DevtoolsSpacing.tabHeight,
            child: const TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(text: 'QUERIES'),
                Tab(text: 'MUTATIONS'),
              ],
              labelStyle: DevtoolsTypography.tab,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                QueriesTab(onQueryTap: onQueryTap),
                MutationsTab(onMutationTap: onMutationTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
