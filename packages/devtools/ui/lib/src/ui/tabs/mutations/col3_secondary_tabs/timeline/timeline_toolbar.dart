import 'package:flutter/material.dart';

/// Toolbar for timeline actions: filter, pause/resume, and clear.
class TimelineToolbar extends StatelessWidget {
  /// Creates timeline toolbar.
  const TimelineToolbar({
    super.key,
    required this.onFilterChanged,
    required this.onTogglePause,
    required this.onClear,
    required this.paused,
  });

  /// Called when filter text changes.
  final ValueChanged<String> onFilterChanged;

  /// Called when pause toggle is pressed.
  final VoidCallback onTogglePause;

  /// Called when clear is pressed.
  final VoidCallback onClear;

  /// Indicates whether stream updates are paused.
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Filter…',
            ),
            onChanged: onFilterChanged,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onTogglePause,
          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
          label: Text(paused ? 'Resume' : 'Pause'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Clear'),
        ),
      ],
    );
  }
}
