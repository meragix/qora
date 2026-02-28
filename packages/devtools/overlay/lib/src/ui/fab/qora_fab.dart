import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/fab/fab_badge.dart';

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
      bottom: 24,
      right: 16,
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
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x663B82F6),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
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
