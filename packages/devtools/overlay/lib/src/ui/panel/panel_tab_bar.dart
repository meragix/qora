import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/panels/mutations/mutations_panel.dart';
import 'package:qora_devtools_overlay/src/ui/panels/queries/queries_panel.dart';

/// Top-level tab bar inside [QoraPanel].
///
/// Two tabs:
/// - **QUERIES** — flat list of all observed query keys with their status.
/// - **MUTATIONS** — 3-column layout (list / inspector / timeline+tabs).
class PanelTabBar extends StatelessWidget {
  const PanelTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'QUERIES'),
              Tab(text: 'MUTATIONS'),
            ],
            labelColor: Color(0xFFE2E8F0),
            unselectedLabelColor: Color(0xFF475569),
            indicatorColor: Color(0xFF3B82F6),
            labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                QueriesPanelView(),
                MutationsTabView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
