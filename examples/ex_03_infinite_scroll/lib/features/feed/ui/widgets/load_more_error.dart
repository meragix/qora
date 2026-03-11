import 'package:flutter/material.dart';

/// Shown at the bottom of the feed when a load-more (next-page) fetch fails.
///
/// Displayed as a list footer so the successfully loaded posts above remain
/// fully visible — this implements [InfiniteFailure.previousData] graceful
/// degradation at the UI layer.
class LoadMoreErrorBanner extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const LoadMoreErrorBanner({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to load more posts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$error',
            style: TextStyle(fontSize: 12, color: Colors.red.shade600),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
