import 'package:flutter/material.dart';

/// Data Diff tab — column 3, third tab of the Mutations panel.
///
/// Planned feature: shows a before/after diff of the cache entry affected by
/// the selected mutation. Currently a "coming soon" placeholder.
class DataDiffTab extends StatelessWidget {
  const DataDiffTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.difference_outlined, color: Color(0xFF334155), size: 32),
          SizedBox(height: 8),
          Text(
            'Data Diff',
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
