import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/queries_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

class PanelHeader extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onToggleExpand;
  final bool isExpanded;

  const PanelHeader({
    super.key,
    required this.onClose,
    required this.onToggleExpand,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeCount = context.watch<QueriesNotifier>().activeQueryCount;

    return Container(
      color: DevtoolsColors.background,
      height: DevtoolsSpacing.panelHeaderHeight,
      padding: 16.edgeInsetsH,
      child: Row(
        children: [
          // Logo Q
          const Text(
            'Q',
            style: TextStyle(
              color: DevtoolsColors.accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Qora Devtools',
            style: DevtoolsTypography.sectionTitle,
          ),
          const SizedBox(width: 8),
          // Badge "5 queries active"
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: DevtoolsColors.accent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$activeCount ${activeCount == 1 ? 'query' : 'queries'} active',
                style: DevtoolsTypography.smallMuted
                    .copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          const Spacer(),
          // Expand
          IconButton(
            icon: Icon(
                isExpanded ? LucideIcons.minimize2 : LucideIcons.maximize2,
                size: 16),
            onPressed: onToggleExpand,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          // Close
          IconButton(
            icon: const Icon(LucideIcons.x, size: 16),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}
