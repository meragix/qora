import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_queue_notifier.dart';
import 'package:qora_devtools_overlay/src/domain/query_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/inspector_panel.dart';
import 'package:qora_devtools_overlay/src/ui/panel/layout/panel_layout.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/left_panel.dart';
import 'package:qora_devtools_overlay/src/ui/panel/secondary/timeline_tab.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

class PanelBody extends StatefulWidget {
  const PanelBody({super.key});

  @override
  State<PanelBody> createState() => _PanelBodyState();
}

class _PanelBodyState extends State<PanelBody> {
  PanelScreen _mobileScreen = PanelScreen.list;

  InspectorKind _inspector = InspectorKind.query;

  void _showInspector(InspectorKind kind) {
    final isMobile = MediaQuery.sizeOf(context).width < kMobileBreakpoint;
    setState(() {
      _inspector = kind;
      if (isMobile) _mobileScreen = PanelScreen.inspector;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PanelLayout(
      currentScreen: _mobileScreen,
      onNavigate: (s) => setState(() => _mobileScreen = s),

      // ── Col 1 : Queries / Mutations / Queue lists ────────────────────────
      listColumn: LeftPanel(
        onTabChanged: (index) => setState(
          () => _inspector = InspectorKind.values[index],
        ),
        onQueryTap: (query) {
          context.read<QueryInspectorNotifier>().select(query);
          _showInspector(InspectorKind.query);
        },
        onMutationTap: (mutation) {
          context.read<MutationInspectorNotifier>().select(mutation);
          _showInspector(InspectorKind.mutation);
        },
        onQueueEntryTap: (entry) {
          context.read<MutationQueueNotifier>().select(entry);
          _showInspector(InspectorKind.queue);
        },
      ),

      // ── Col 2 : Inspector of the selection ───────────────────────────────
      inspectorColumn: InspectorPanel(kind: _inspector),

      // ── Col 3 : Timeline ─────────────────────────────────────────────────
      secondaryColumn: DefaultTabController(
        length: 1,
        child: Column(children: [
          SizedBox(
            height: DevtoolsSpacing.tabHeight,
            child: const TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [Tab(text: 'TIMELINE')],
              labelStyle: DevtoolsTypography.tab,
            ),
          ),
          const Expanded(child: TimelineTab()),
        ]),
      ),
    );
  }
}
