import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/screens/mutation_timeline_screen.dart';
import 'package:qora_devtools_ui/src/ui/screens/optimistic_updates_screen.dart';
import 'package:qora_devtools_ui/src/ui/shell/devtools_header.dart';
import 'package:qora_devtools_ui/src/ui/shell/main_tab_bar.dart';
import 'package:qora_devtools_ui/src/ui/state/cache_controller.dart';
import 'package:qora_devtools_ui/src/ui/state/timeline_controller.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutation_inspector/mutation_inspector_tab.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/mutations_tab.dart';
import 'package:qora_devtools_ui/src/ui/tabs/queries/queries_tab.dart';

/// Global shell layout: header + main tabs + tab views.
class AppShell extends StatefulWidget {
  /// Creates an app shell.
  const AppShell({
    super.key,
    required this.timelineController,
    required this.cacheController,
  });

  /// Timeline state controller.
  final TimelineController timelineController;

  /// Cache state controller.
  final CacheController cacheController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const DevtoolsHeader(activeQueryCount: 0),
        bottom: MainTabBar(controller: _tabController),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          QueriesTab(cacheController: widget.cacheController),
          MutationsTab(
            timelineController: widget.timelineController,
            fallbackTimeline: MutationTimelineScreen(
              controller: widget.timelineController,
            ),
          ),
          MutationInspectorTab(
            fallback: OptimisticUpdatesScreen(
              controller: widget.timelineController,
            ),
          ),
        ],
      ),
    );
  }
}
