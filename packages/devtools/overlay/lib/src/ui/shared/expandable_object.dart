import 'package:flutter/material.dart';

/// Collapsible `> Object(N)` row used in the Mutation Inspector panel.
///
/// Tapping the row toggles the [preview] text visible below the label.
/// The [isError] flag switches the colour scheme to red.
class ExpandableObject extends StatefulWidget {
  final String label;
  final String? preview;
  final bool isError;

  const ExpandableObject({
    super.key,
    required this.label,
    this.preview,
    this.isError = false,
  });

  @override
  State<ExpandableObject> createState() => _ExpandableObjectState();
}

class _ExpandableObjectState extends State<ExpandableObject> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        widget.isError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0);
    final previewColor =
        widget.isError ? const Color(0xFFEF4444) : const Color(0xFF94A3B8);
    final iconColor =
        widget.isError ? const Color(0xFFEF4444) : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(
                _expanded ? Icons.expand_more : Icons.chevron_right,
                size: 14,
                color: iconColor,
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        if (_expanded && widget.preview != null)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 4, bottom: 2),
            child: Text(
              widget.preview!,
              style: TextStyle(
                color: previewColor,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
      ],
    );
  }
}
