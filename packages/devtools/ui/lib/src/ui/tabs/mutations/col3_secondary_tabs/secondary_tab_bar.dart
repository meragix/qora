import 'package:flutter/material.dart';

/// Secondary tab bar shown in the third column of MUTATIONS tab.
class SecondaryTabBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a secondary tab bar.
  const SecondaryTabBar({super.key, required this.controller});

  /// Tab controller for secondary tabs.
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      tabs: const <Tab>[
        Tab(text: 'TIMELINE'),
        Tab(text: 'WIDGET TREE'),
        Tab(text: 'DATA DIFF'),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(44);
}
