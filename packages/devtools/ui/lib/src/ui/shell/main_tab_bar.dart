import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

/// Primary tab bar of the Qora DevTools application.
///
/// Relies entirely on the [TabBarTheme] injected by [DevToolsExtension] via
/// [themeFor] — no custom colours or padding needed here.
class MainTabBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a main tab bar.
  const MainTabBar({super.key, required this.controller});

  /// Tab controller driving the primary tabs.
  final TabController controller;

  static const double _height = 34;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabs: const <Tab>[
          Tab(text: 'QUERIES'),
          Tab(text: 'MUTATIONS'),
          Tab(text: 'INSPECTOR'),
          Tab(text: 'NETWORK'),
          Tab(text: 'PERFORMANCE'),
          Tab(text: 'GRAPH'),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(_height);
}
