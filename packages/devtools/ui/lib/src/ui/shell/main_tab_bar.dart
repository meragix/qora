import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_ui/src/ui/theme/devtools_spacing.dart';

/// Primary tab bar of the Qora DevTools application.
class MainTabBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a main tab bar.
  const MainTabBar({super.key, required this.controller});

  /// Tab controller driving the primary tabs.
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DevtoolsSpacing.tabHeight,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        tabs: const <Widget>[
          _DevtoolsTab('QUERIES'),
          _DevtoolsTab('MUTATIONS'),
          _DevtoolsTab('INSPECTOR'),
          _DevtoolsTab('NETWORK'),
          _DevtoolsTab('PERFORMANCE'),
          _DevtoolsTab('GRAPH'),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(DevtoolsSpacing.tabHeight);
}

class _DevtoolsTab extends StatelessWidget {
  const _DevtoolsTab(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DevtoolsSpacing.tabHeight,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: DevtoolsColors.textMuted,
          ),
        ),
      ),
    );
  }
}
