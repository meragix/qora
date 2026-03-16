import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_ui/src/ui/theme/devtools_spacing.dart';

/// Header displayed at the top of the DevTools extension shell.
class DevtoolsHeader extends StatelessWidget {
  /// Creates a header widget.
  const DevtoolsHeader({
    super.key,
    required this.activeQueryCount,
  });

  /// Number of currently active queries.
  final int activeQueryCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        // Logo mark
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: DevtoolsColors.accent,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Q',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: DevtoolsColors.zinc950,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: DevtoolsSpacing.sm),
        const Text(
          'Qora DevTools',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: DevtoolsColors.textPrimary,
          ),
        ),
        const SizedBox(width: DevtoolsSpacing.md),
        if (activeQueryCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: DevtoolsColors.accent.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: DevtoolsColors.accent.withValues(alpha: .3),
              ),
            ),
            child: Text(
              '$activeQueryCount active',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: DevtoolsColors.accent,
              ),
            ),
          ),
        const Spacer(),
        IconButton(
          tooltip: 'Expand',
          onPressed: () {},
          icon: const Icon(Icons.open_in_full, size: 16),
          color: DevtoolsColors.textMuted,
          hoverColor: DevtoolsColors.rowHover,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
