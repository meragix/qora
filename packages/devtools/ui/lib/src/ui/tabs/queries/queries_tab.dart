import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/screens/cache_inspector_screen.dart';
import 'package:qora_devtools_ui/src/ui/state/cache_controller.dart';

/// Main content of the QUERIES tab.
class QueriesTab extends StatelessWidget {
  /// Creates queries tab.
  const QueriesTab({
    super.key,
    required this.cacheController,
  });

  /// Cache controller bound to the tab.
  final CacheController cacheController;

  @override
  Widget build(BuildContext context) {
    return CacheInspectorScreen(controller: cacheController);
  }
}
