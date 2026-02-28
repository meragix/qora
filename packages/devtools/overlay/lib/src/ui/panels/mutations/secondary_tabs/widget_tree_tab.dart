import 'package:flutter/material.dart';

/// Widget Tree tab — column 3, second tab of the Mutations panel.
///
/// Planned feature: shows the widget tree at the time of the selected mutation.
/// Currently a "coming soon" placeholder.
class WidgetTreeTab extends StatelessWidget {
  const WidgetTreeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_tree_outlined, color: Color(0xFF334155), size: 32),
          SizedBox(height: 8),
          Text(
            'Widget Tree',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Coming soon',
            style: TextStyle(color: Color(0xFF334155), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
