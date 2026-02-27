import 'package:flutter/material.dart';

/// Compact expandable preview for serialized object values.
class ExpandableObject extends StatefulWidget {
  /// Creates an expandable object view.
  const ExpandableObject({
    super.key,
    required this.label,
    this.body,
    this.isError = false,
  });

  /// Collapsed line label.
  final String label;

  /// Optional expanded widget body.
  final Widget? body;

  /// Whether the value should use error styling.
  final bool isError;

  @override
  State<ExpandableObject> createState() => _ExpandableObjectState();
}

class _ExpandableObjectState extends State<ExpandableObject> {
  @override
  Widget build(BuildContext context) {
    final color = widget.isError
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        title: Text(widget.label),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8),
            child: widget.body ?? const Text('No content'),
          ),
        ],
        onExpansionChanged: (_) {},
      ),
    );
  }
}
