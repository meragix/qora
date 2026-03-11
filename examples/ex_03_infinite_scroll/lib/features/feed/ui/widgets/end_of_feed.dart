import 'package:flutter/material.dart';

/// Shown at the bottom of the feed when [InfiniteSuccess.hasNextPage] is
/// false — all available posts have been loaded.
class EndOfFeedBanner extends StatelessWidget {
  const EndOfFeedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 32,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              "You're all caught up!",
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
