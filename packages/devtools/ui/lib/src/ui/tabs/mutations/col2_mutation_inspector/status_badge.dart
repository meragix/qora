import 'package:flutter/material.dart';

/// Status badge used in mutation inspector.
class StatusBadge extends StatelessWidget {
  /// Creates a status badge.
  const StatusBadge({
    super.key,
    required this.label,
  });

  /// Badge label.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
