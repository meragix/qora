import 'package:flutter/material.dart';

/// Primary tab bar of the Qora DevTools application.
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
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
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
