import 'package:flutter/material.dart';

/// Dedicated top-level tab for mutation inspector when layout space is limited.
class MutationInspectorTab extends StatelessWidget {
  /// Creates mutation inspector tab.
  const MutationInspectorTab({
    super.key,
    required this.fallback,
  });

  /// Temporary fallback content.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return fallback;
  }
}
