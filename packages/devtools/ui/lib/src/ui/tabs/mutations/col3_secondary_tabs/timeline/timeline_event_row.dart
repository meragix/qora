import 'package:flutter/material.dart';

/// Visual row for one timeline event.
class TimelineEventRow extends StatelessWidget {
  /// Creates timeline event row.
  const TimelineEventRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  /// Event title.
  final String title;

  /// Event secondary line.
  final String subtitle;

  /// Event timestamp text.
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.bolt, size: 16),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(timestamp),
    );
  }
}
