import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/domain/query_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/inspector_panel.dart';
import 'package:qora_devtools_overlay/src/ui/panel/layout/panel_layout.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/left_panel.dart';
import 'package:qora_devtools_overlay/src/ui/panel/secondary/data_diff_tab.dart';
import 'package:qora_devtools_overlay/src/ui/panel/secondary/timeline_tab.dart';
import 'package:qora_devtools_overlay/src/ui/panel/secondary/widget_tree_tab.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

class PanelBody extends StatefulWidget {
  const PanelBody({super.key});

  @override
  State<PanelBody> createState() => _PanelBodyState();
}

class _PanelBodyState extends State<PanelBody> {
  PanelScreen _mobileScreen = PanelScreen.list;

  // Tracks whether the inspector shows a query (true) or a mutation (false).
  bool _showQueryInspector = true;

  @override
  Widget build(BuildContext context) {
    return PanelLayout(
      currentScreen: _mobileScreen,
      onNavigate: (s) => setState(() => _mobileScreen = s),

      // ── Col 1 : Queries / Mutations list ─────────────────────────────────
      listColumn: LeftPanel(
        onTabChanged: (index) => setState(() => _showQueryInspector = index == 0),
        onQueryTap: (query) {
          context.read<QueryInspectorNotifier>().select(query);
          final isMobile = MediaQuery.sizeOf(context).width < kMobileBreakpoint;
          setState(() {
            _showQueryInspector = true;
            if (isMobile) _mobileScreen = PanelScreen.inspector;
          });
        },
        onMutationTap: (mutation) {
          context.read<MutationInspectorNotifier>().select(mutation);
          final isMobile = MediaQuery.sizeOf(context).width < kMobileBreakpoint;
          setState(() {
            _showQueryInspector = false;
            if (isMobile) _mobileScreen = PanelScreen.inspector;
          });
        },
      ),

      // ── Col 2 : Query / Mutation Inspector ───────────────────────────────
      inspectorColumn: InspectorPanel(showQuery: _showQueryInspector),

      // ── Col 3 : Secondary tabs (Timeline / Widget Tree / Data Diff) ──────
      secondaryColumn: DefaultTabController(
        length: 3,
        child: Column(children: [
          SizedBox(
            height: DevtoolsSpacing.tabHeight,
            child: const TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(text: 'TIMELINE'),
                Tab(text: 'WIDGET TREE'),
                Tab(text: 'DATA DIFF'),
              ],
              labelStyle: DevtoolsTypography.tab,
            ),
          ),
          const Expanded(
            child: TabBarView(children: [
              TimelineTab(),
              WidgetTreeTab(),
              DataDiffTab(),
            ]),
          ),
        ]),
      ),
    );
  }
}
