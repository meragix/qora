import 'package:flutter/material.dart';

/// Uppercase subtle section label used by inspector blocks.
class SectionLabel extends StatelessWidget {
  /// Creates section label.
  const SectionLabel({
    super.key,
    required this.text,
  });

  /// Label text.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
