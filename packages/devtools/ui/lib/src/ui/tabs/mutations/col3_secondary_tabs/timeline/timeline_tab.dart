import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/state/timeline_controller.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col3_secondary_tabs/data_diff/data_diff_tab.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col3_secondary_tabs/secondary_tab_bar.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col3_secondary_tabs/timeline/timeline_event_row.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col3_secondary_tabs/timeline/timeline_toolbar.dart';
import 'package:qora_devtools_ui/src/ui/tabs/mutations/col3_secondary_tabs/widget_tree/widget_tree_tab.dart';

/// Right column with secondary tabs and event timeline.
class TimelineTab extends StatefulWidget {
  /// Creates timeline tab container.
  const TimelineTab({
    super.key,
    required this.controller,
    required this.fallback,
  });

  /// Timeline state controller.
  final TimelineController controller;

  /// Fallback widget to preserve backward compatibility.
  final Widget fallback;

  @override
  State<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<TimelineTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _filter = '';
  bool _paused = false;

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
    return Column(
      children: <Widget>[
        SecondaryTabBar(controller: _tabController),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TimelineToolbar(
                      onFilterChanged: (value) =>
                          setState(() => _filter = value),
                      onTogglePause: () => setState(() => _paused = !_paused),
                      onClear: widget.controller.clear,
                      paused: _paused,
                    ),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: widget.controller,
                      builder: (context, _) {
                        final events = widget.controller.events
                            .where(
                              (event) =>
                                  _filter.isEmpty ||
                                  event.kind.contains(_filter),
                            )
                            .toList(growable: false);

                        if (events.isEmpty) {
                          return widget.fallback;
                        }

                        return ListView.builder(
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            final event = events[index];
                            return TimelineEventRow(
                              title: event.kind,
                              subtitle: event.eventId,
                              timestamp: '${event.timestampMs}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              const WidgetTreeTab(),
              const DataDiffTab(),
            ],
          ),
        ),
      ],
    );
  }
}
