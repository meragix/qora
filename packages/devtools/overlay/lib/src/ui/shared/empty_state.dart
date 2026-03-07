import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

/// Generic empty-state message widget.
class EmptyState extends StatelessWidget {
  /// Creates empty state widget.
  const EmptyState({
    super.key,
    required this.message,
  });

  /// Empty-state message.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, style: DevtoolsTypography.bodyMuted));
  }
}
