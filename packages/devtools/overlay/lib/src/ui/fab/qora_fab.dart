import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/fab/fab_badge.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_shadows.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';

/// Floating action button that opens the Qora DevTools overlay panel.
///
/// Positioned in the bottom-right corner of the screen. Shows a [FabBadge]
/// with the active query count when queries are loading.
class QoraFab extends StatelessWidget {
  final VoidCallback onTap;

  const QoraFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: DevtoolsSpacing.xxl,
      right: DevtoolsSpacing.lg,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:  BoxDecoration(
                  color: DevtoolsColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: DevtoolsShadows.fab,
                ),
                child: const Center(
                  child: Text(
                    'Q',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const FabBadge(),
            ],
          ),
        ),
      ),
    );
  }
}
