import 'package:flutter/material.dart';

/// Colored status marker used in mutations lists.
class StatusDot extends StatelessWidget {
  /// Creates a status dot.
  const StatusDot({
    super.key,
    this.color,
  });

  /// Dot color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.circle,
      size: 10,
      color: color ?? Theme.of(context).colorScheme.primary,
    );
  }
}
