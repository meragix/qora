import 'package:flutter/material.dart';

/// Recursively renders a JSON value as an expandable tree.
///
/// Supports [Map], [List], and primitive types (String, num, bool, null).
/// Nodes deeper than [maxDepth] are collapsed by default and show a
/// "…expand…" placeholder to avoid unbounded widget trees.
class JsonTreeViewer extends StatelessWidget {
  /// Creates a tree viewer for [value].
  const JsonTreeViewer({
    super.key,
    required this.value,
    this.maxDepth = 5,
  });

  /// The JSON value to render.
  final Object? value;

  /// Maximum depth before nodes are shown collapsed.
  final int maxDepth;

  @override
  Widget build(BuildContext context) {
    return _JsonNode(value: value, depth: 0, maxDepth: maxDepth);
  }
}

// ── Internal node ─────────────────────────────────────────────────────────────

class _JsonNode extends StatefulWidget {
  const _JsonNode({
    required this.value,
    required this.depth,
    required this.maxDepth,
    this.label,
  });

  final Object? value;
  final int depth;
  final int maxDepth;
  final String? label;

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.depth < widget.maxDepth;
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final label = widget.label;

    if (value is Map) {
      return _buildCollapsible(
        label: label,
        preview: '{${value.length}}',
        children: value.entries
            .map(
              (e) => _JsonNode(
                label: '"${e.key}"',
                value: e.value,
                depth: widget.depth + 1,
                maxDepth: widget.maxDepth,
              ),
            )
            .toList(growable: false),
      );
    }

    if (value is List) {
      return _buildCollapsible(
        label: label,
        preview: '[${value.length}]',
        children: value
            .asMap()
            .entries
            .map(
              (e) => _JsonNode(
                label: '${e.key}',
                value: e.value,
                depth: widget.depth + 1,
                maxDepth: widget.maxDepth,
              ),
            )
            .toList(growable: false),
      );
    }

    return _buildLeaf(label: label, value: value);
  }

  Widget _buildCollapsible({
    required String? label,
    required String preview,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: <Widget>[
              Icon(
                _expanded
                    ? Icons.arrow_drop_down
                    : Icons.arrow_right,
                size: 16,
                color: const Color(0xFF64748B),
              ),
              if (label != null) ...<Widget>[
                Text(
                  '$label: ',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
              Text(
                preview,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
      ],
    );
  }

  Widget _buildLeaf({required String? label, required Object? value}) {
    final (text, color) = _formatPrimitive(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(width: 16),
          if (label != null)
            Text(
              '$label: ',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _formatPrimitive(Object? value) => switch (value) {
        null => ('null', const Color(0xFF94A3B8)),
        bool v => ('$v', const Color(0xFFF59E0B)),
        num v => ('$v', const Color(0xFF60A5FA)),
        String v => ('"$v"', const Color(0xFF34D399)),
        _ => ('$value', const Color(0xFFE2E8F0)),
      };
}
