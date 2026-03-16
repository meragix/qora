import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_ui/src/ui/theme/devtools_typography.dart';

/// Generic empty-state message widget.
class EmptyState extends StatelessWidget {
  /// Creates empty state widget.
  const EmptyState({
    super.key,
    required this.message,
    this.icon,
  });

  /// Empty-state message.
  final String message;

  /// Optional icon shown above the message.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...[
            Icon(icon, size: 32, color: DevtoolsColors.textDisabled),
            const SizedBox(height: 12),
          ],
          Text(message, style: DevtoolsTypography.smallMuted),
        ],
      ),
    );
  }
}
