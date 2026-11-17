import 'package:flutter/material.dart';
import 'package:qora/qora.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/queries/queries_tab.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/mutations/mutations_tab.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/queue/queue_tab.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class LeftPanel extends StatefulWidget {
  final void Function(QueryEvent) onQueryTap;
  final void Function(MutationEvent) onMutationTap;
  final void Function(QueuedMutation) onQueueEntryTap;

  /// Called with `0` (queries), `1` (mutations) or `2` (queue) when the tab
  /// changes.
  final void Function(int index) onTabChanged;

  const LeftPanel({
    super.key,
    required this.onQueryTap,
    required this.onMutationTap,
    required this.onQueueEntryTap,
    required this.onTabChanged,
  });

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        widget.onTabChanged(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: DevtoolsSpacing.tabHeight,
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'QUERIES'),
              Tab(text: 'MUTATIONS'),
              Tab(text: 'QUEUE'),
            ],
            labelStyle: DevtoolsTypography.tab,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              QueriesTab(onQueryTap: widget.onQueryTap),
              MutationsTab(onMutationTap: widget.onMutationTap),
              QueueTab(onEntryTap: widget.onQueueEntryTap),
            ],
          ),
        ),
      ],
    );
  }
}
