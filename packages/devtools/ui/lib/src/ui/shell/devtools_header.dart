import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/theme/devtools_colors.dart';

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
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        // Logo mark — accent purple, always visible regardless of host theme
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: DevtoolsColors.accent,
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Q',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('Qora DevTools', style: theme.textTheme.titleSmall),
        const SizedBox(width: 10),
        if (activeQueryCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$activeQueryCount active',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        const Spacer(),
        IconButton(
          tooltip: 'Expand',
          onPressed: () {},
          icon: const Icon(Icons.open_in_full, size: 14),
        ),
      ],
    );
  }
}
