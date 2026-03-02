import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/domain/dependency_notifier.dart';
import 'package:qora_devtools_ui/src/domain/network_activity_notifier.dart';
import 'package:qora_devtools_ui/src/domain/performance_notifier.dart';
import 'package:qora_devtools_ui/src/domain/queries_notifier.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';
import 'package:qora_devtools_ui/src/domain/usecases/fetch_large_payload.dart';
import 'package:qora_devtools_ui/src/domain/usecases/refetch_query.dart';
import 'package:qora_devtools_ui/src/ui/screens/cache_inspector_screen.dart';
import 'package:qora_devtools_ui/src/ui/screens/dependency_graph_screen.dart';
import 'package:qora_devtools_ui/src/ui/screens/mutation_timeline_screen.dart';
import 'package:qora_devtools_ui/src/ui/screens/network_activity_screen.dart';
import 'package:qora_devtools_ui/src/ui/screens/optimistic_updates_screen.dart';
import 'package:qora_devtools_ui/src/ui/screens/performance_screen.dart';
import 'package:qora_devtools_ui/src/ui/shell/devtools_header.dart';
import 'package:qora_devtools_ui/src/ui/shell/main_tab_bar.dart';
import 'package:qora_devtools_ui/src/ui/state/cache_controller.dart';
import 'package:qora_devtools_ui/src/ui/state/timeline_controller.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutation_inspector/mutation_inspector_tab.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/mutations_tab.dart';

/// Global shell layout: header + main tabs + tab views.
class AppShell extends StatefulWidget {
  /// Creates an app shell.
  const AppShell({
    super.key,
    required this.timelineController,
    required this.cacheController,
    required this.queriesNotifier,
    required this.networkNotifier,
    required this.performanceNotifier,
    required this.dependencyNotifier,
    required this.refetch,
    required this.fetchLargePayload,
    required this.repository,
  });

  /// Timeline state controller.
  final TimelineController timelineController;

  /// Cache state controller.
  final CacheController cacheController;

  /// Live query list notifier.
  final QueriesNotifier queriesNotifier;

  /// Network activity notifier.
  final NetworkActivityNotifier networkNotifier;

  /// Performance metrics notifier.
  final PerformanceNotifier performanceNotifier;

  /// Dependency graph notifier.
  final DependencyNotifier dependencyNotifier;

  /// Refetch use-case forwarded to query rows.
  final RefetchQueryUseCase refetch;

  /// Large payload use-case forwarded to query rows.
  final FetchLargePayloadUseCase fetchLargePayload;

  /// Repository for dispatching invalidate commands.
  final EventRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
        title: AnimatedBuilder(
          animation: widget.queriesNotifier,
          builder: (context, _) => DevtoolsHeader(
            activeQueryCount: widget.queriesNotifier.activeQueryCount,
          ),
        ),
        bottom: MainTabBar(controller: _tabController),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          // Tab 0 — Queries
          CacheInspectorScreen(
            controller: widget.cacheController,
            queriesNotifier: widget.queriesNotifier,
            refetch: widget.refetch,
            fetchLargePayload: widget.fetchLargePayload,
            repository: widget.repository,
          ),
          // Tab 1 — Mutations
          MutationsTab(
            timelineController: widget.timelineController,
            fallbackTimeline: MutationTimelineScreen(
              controller: widget.timelineController,
            ),
          ),
          // Tab 2 — Mutation Inspector
          MutationInspectorTab(
            fallback: OptimisticUpdatesScreen(
              controller: widget.timelineController,
            ),
          ),
          // Tab 3 — Network
          NetworkActivityScreen(notifier: widget.networkNotifier),
          // Tab 4 — Performance
          PerformanceScreen(notifier: widget.performanceNotifier),
          // Tab 5 — Dependency Graph
          DependencyGraphScreen(notifier: widget.dependencyNotifier),
        ],
      ),
    );
  }
}
