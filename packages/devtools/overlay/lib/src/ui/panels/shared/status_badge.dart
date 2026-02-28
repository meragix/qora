import 'package:flutter/material.dart';

/// Coloured pill badge displaying a mutation or query status string.
///
/// Supported status values and their colours:
///
/// | Status      | Background          | Text                |
/// |-------------|---------------------|---------------------|
/// | `success`   | dark green          | green               |
/// | `error`     | dark red            | red                 |
/// | `pending`   | dark indigo         | purple              |
/// | `loading`   | dark blue           | blue                |
/// | _(other)_   | slate               | slate               |
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'success' => (const Color(0xFF14532D), const Color(0xFF22C55E)),
      'error' => (const Color(0xFF450A0A), const Color(0xFFEF4444)),
      'pending' => (const Color(0xFF1E1B4B), const Color(0xFF8B5CF6)),
      'loading' => (const Color(0xFF1E3A5F), const Color(0xFF3B82F6)),
      _ => (const Color(0xFF1E293B), const Color(0xFF64748B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
