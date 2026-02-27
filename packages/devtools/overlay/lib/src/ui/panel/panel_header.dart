import 'package:flutter/material.dart';

class PanelHeader extends StatelessWidget {
  final VoidCallback onClose;
  const PanelHeader({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final activeCount = context.watch<QueriesNotifier>().activeQueryCount;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Logo Q
          const Text(
            'Q',
            style: TextStyle(
              color: Color(0xFF3B82F6),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Qora Devtools',
            style: TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          // Badge "5 queries active"
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$activeCount ${activeCount == 1 ? 'query' : 'queries'} active',
                style: const TextStyle(
                  color: Color(0xFF93C5FD),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const Spacer(),
          // Expand
          IconButton(
            icon: const Icon(Icons.open_in_full_rounded, color: Color(0xFF475569), size: 16),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          // Close
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF475569), size: 16),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}
