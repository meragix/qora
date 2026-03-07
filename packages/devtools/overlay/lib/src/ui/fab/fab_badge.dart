import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/queries_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';

/// Red counter badge shown on the [QoraFab] when queries are loading.
///
/// Hidden when [QueriesNotifier.activeQueryCount] is zero. Positioned at the
/// top-right corner of the FAB by the parent [Stack].
class FabBadge extends StatelessWidget {
  const FabBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<QueriesNotifier>().activeQueryCount;
    if (count == 0) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        width: DevtoolsSpacing.lg,
        height: DevtoolsSpacing.lg,
        decoration: const BoxDecoration(
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
