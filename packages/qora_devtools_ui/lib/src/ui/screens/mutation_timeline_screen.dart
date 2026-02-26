import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/state/timeline_controller.dart';

/// Screen showing the runtime event timeline.
class MutationTimelineScreen extends StatelessWidget {
  /// Creates the timeline screen.
  const MutationTimelineScreen({
    super.key,
    required this.controller,
  });

  /// State controller providing timeline data and actions.
  final TimelineController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final events = controller.events;
        if (events.isEmpty) {
          return const Center(
            child: Text('No events yet. Connect the app to start streaming.'),
          );
        }

        return ListView.separated(
          itemCount: events.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final event = events[index];
            return ListTile(
              dense: true,
              title: Text(event.kind),
              subtitle: Text('id: ${event.eventId}'),
              trailing: Text('${event.timestampMs}'),
            );
          },
        );
      },
    );
  }
}
