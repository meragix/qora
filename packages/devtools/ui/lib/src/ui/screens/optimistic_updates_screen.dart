import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/state/timeline_controller.dart';

/// Screen dedicated to optimistic update related events.
class OptimisticUpdatesScreen extends StatelessWidget {
  /// Creates optimistic updates screen.
  const OptimisticUpdatesScreen({
    super.key,
    required this.controller,
  });

  /// Shared timeline controller.
  final TimelineController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final optimisticEvents = controller.events
            .where((event) => event.kind.startsWith('optimistic.'))
            .toList(growable: false);

        if (optimisticEvents.isEmpty) {
          return const Center(
            child: Text('No optimistic update events received.'),
          );
        }

        return ListView.separated(
          itemCount: optimisticEvents.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final event = optimisticEvents[index];
            return ListTile(
              dense: true,
              title: Text(event.kind),
              subtitle: Text('id: ${event.eventId}'),
            );
          },
        );
      },
    );
  }
}
