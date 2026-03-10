import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';

/// Widget Tree tab — column 3, second tab of the Mutations panel.
///
/// Planned feature: shows the widget tree at the time of the selected mutation.
/// Currently a "coming soon" placeholder.
class WidgetTreeTab extends StatelessWidget {
  const WidgetTreeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.listTree, color: DevtoolsColors.textMuted, size: 32),
          SizedBox(height: 8),
          Text(
            'Widget Tree',
            style: TextStyle(
              color: DevtoolsColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Coming soon',
            style: TextStyle(color: DevtoolsColors.textDisabled, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
