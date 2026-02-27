import 'package:flutter/material.dart';

/// Generic empty-state message widget.
class EmptyState extends StatelessWidget {
  /// Creates empty state widget.
  const EmptyState({
    super.key,
    required this.message,
  });

  /// Empty-state message.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
