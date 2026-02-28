import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/panel/panel_header.dart';
import 'package:qora_devtools_overlay/src/ui/panel/panel_tab_bar.dart';

/// The main DevTools panel — a dark sheet anchored to the bottom of the screen.
///
/// Contains [PanelHeader] (close / expand controls) and [PanelTabBar]
/// (QUERIES / MUTATIONS tabs). Mounted above the app content by [QoraInspector].
class QoraPanel extends StatelessWidget {
  final VoidCallback onClose;

  const QoraPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.6;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: height,
      child: Material(
        color: const Color(0xFF0F172A),
        elevation: 8,
        child: Column(
          children: [
            PanelHeader(onClose: onClose),
            const Divider(height: 1, thickness: 1, color: Color(0xFF1E293B)),
            const Expanded(child: PanelTabBar()),
          ],
        ),
      ),
    );
  }
}
