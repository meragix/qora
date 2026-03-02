import 'package:flutter/material.dart';

/// Primary tab bar of the Qora DevTools application.
class MainTabBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a main tab bar.
  const MainTabBar({super.key, required this.controller});

  /// Tab controller driving the primary tabs.
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      tabs: const <Tab>[
        Tab(text: 'QUERIES'),
        Tab(text: 'MUTATIONS'),
        Tab(text: 'MUTATION INSPECTOR'),
        Tab(text: 'NETWORK'),
        Tab(text: 'PERFORMANCE'),
        Tab(text: 'GRAPH'),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}
