import 'package:flutter/material.dart';

/// Action button used to retry the selected mutation.
class RetryButton extends StatelessWidget {
  /// Creates a retry button.
  const RetryButton({super.key, this.onPressed});

  /// Callback for retry action.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh),
      label: const Text('Retry'),
    );
  }
}
