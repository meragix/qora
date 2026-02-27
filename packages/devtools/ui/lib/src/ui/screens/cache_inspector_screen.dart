import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/state/cache_controller.dart';

/// Screen for inspecting the current cache snapshot.
class CacheInspectorScreen extends StatelessWidget {
  /// Creates cache inspector screen.
  const CacheInspectorScreen({
    super.key,
    required this.controller,
  });

  /// Cache state controller.
  final CacheController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error case final error?) {
          return Center(child: Text('Error: $error'));
        }

        final snapshot = controller.snapshot;
        if (snapshot == null) {
          return const Center(
            child: Text('No snapshot loaded yet. Click refresh to fetch one.'),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            Text('Queries: ${snapshot.queries.length}'),
            const SizedBox(height: 8),
            Text('Mutations: ${snapshot.mutations.length}'),
            const SizedBox(height: 8),
            Text('Emitted at: ${snapshot.emittedAtMs}'),
          ],
        );
      },
    );
  }
}
