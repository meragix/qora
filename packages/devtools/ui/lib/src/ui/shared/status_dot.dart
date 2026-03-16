import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/theme/devtools_colors.dart';

/// Colored status marker used in list rows.
class StatusDot extends StatelessWidget {
  /// Creates a status dot.
  const StatusDot({
    super.key,
    this.color,
  });

  /// Dot color. Defaults to [DevtoolsColors.statusIdle].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.circle,
      size: 10,
      color: color ?? DevtoolsColors.statusIdle,
    );
  }
}
