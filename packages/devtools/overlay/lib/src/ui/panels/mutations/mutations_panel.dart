import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/responsive_panel_layout.dart';
import 'package:qora_devtools_overlay/src/ui/panels/mutations/mutation_inspector_panel.dart';
import 'package:qora_devtools_overlay/src/ui/panels/mutations/mutation_row.dart';
import 'package:qora_devtools_overlay/src/ui/panels/mutations/secondary_tabs/data_diff_tab.dart';
import 'package:qora_devtools_overlay/src/ui/panels/mutations/secondary_tabs/timeline_tab.dart';
import 'package:qora_devtools_overlay/src/ui/panels/mutations/secondary_tabs/widget_tree_tab.dart';

class MutationsTabView extends StatefulWidget {
  const MutationsTabView({super.key});
  @override
  State<MutationsTabView> createState() => _MutationsTabViewState();
}

class _MutationsTabViewState extends State<MutationsTabView> {
  PanelScreen _mobileScreen = PanelScreen.list;

  @override
  Widget build(BuildContext context) {
    final inspector = context.watch<MutationInspectorNotifier>();

    return ResponsivePanelLayout(
      currentScreen: _mobileScreen,
      onNavigate: (s) => setState(() => _mobileScreen = s),

      // ── Col 1 : liste des mutations ────────────────────────────
      listColumn: MutationListColumn(
        onMutationTap: (mutation) {
          inspector.select(mutation);
          final isMobile =
              MediaQuery.sizeOf(context).width < kMobileBreakpoint;
          if (isMobile) setState(() => _mobileScreen = PanelScreen.inspector);
        },
      ),

      // ── Col 2 : inspector ──────────────────────────────────────
      inspectorColumn: const MutationInspectorColumn(),

      // ── Col 3 : tabs secondaires (Timeline / Widget Tree / Data Diff)
      secondaryColumn: DefaultTabController(
        length: 3,
        child: Column(children: [
          const TabBar(
            tabs: [
              Tab(text: 'TIMELINE'),
              Tab(text: 'WIDGET TREE'),
              Tab(text: 'DATA DIFF'),
            ],
            labelColor: Color(0xFFE2E8F0),
            unselectedLabelColor: Color(0xFF475569),
            indicatorColor: Color(0xFF3B82F6),
            labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
