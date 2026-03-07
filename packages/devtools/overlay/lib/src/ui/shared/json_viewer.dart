import 'package:flutter/material.dart';
import 'json_value.dart';

// ─────────────────────────────────────────────
// Colour palette (mirrors the React component)
// ─────────────────────────────────────────────
class _C {
  static const null_ = Color(0xFF94A3B8); // slate-400
  static const string_ = Color(0xFFFBBF24); // amber-400
  static const number_ = Color(0xFF22D3EE); // cyan-400
  static const bool_ = Color(0xFFA78BFA); // violet-400
  static const key_ = Color(0xFF22D3EE); // cyan-400  (same as number)
  static const bracket_ = Color(0xFF94A3B8); // slate-400
  static const chevron_ = Color(0xFF64748B); // slate-500
  static const indent_ = Color(0xFF334155); // slate-700
}

// ─────────────────────────────────────────────
// Entry point — accepts raw dynamic
// ─────────────────────────────────────────────

/// Drop-in replacement for the React JSONViewer.
///
/// ```dart
/// JsonViewer(data: response.data)
/// ```
class JsonViewer extends StatelessWidget {
  /// Any value: Map, List, String, num, bool, null — or a pre-built [JsonValue].
  final dynamic data;

  /// Max number of nesting levels auto-expanded on first render.
  final int autoExpandDepth;

  const JsonViewer({
    super.key,
    required this.data,
    this.autoExpandDepth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final value = data is JsonValue ? data as JsonValue : JsonValue.fromDynamic(data);

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: _JsonNode(
        value: value,
        depth: 0,
        autoExpandDepth: autoExpandDepth,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Recursive node — dispatches on sealed type
// ─────────────────────────────────────────────

class _JsonNode extends StatelessWidget {
  final JsonValue value;
  final int depth;
  final int autoExpandDepth;

  const _JsonNode({
    required this.value,
    required this.depth,
    required this.autoExpandDepth,
  });

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      JsonNull() => const _PrimitiveChip(text: 'null', color: _C.null_),
      JsonBool v => _PrimitiveChip(text: v.value.toString(), color: _C.bool_),
      JsonNumber v => _PrimitiveChip(text: v.value.toString(), color: _C.number_),
      JsonString v => _PrimitiveChip(text: '"${v.value}"', color: _C.string_),
      JsonArray v => _ExpandableNode(
          value: v,
          depth: depth,
          autoExpandDepth: autoExpandDepth,
        ),
      JsonObject v => _ExpandableNode(
          value: v,
          depth: depth,
          autoExpandDepth: autoExpandDepth,
        ),
    };
  }
}

// ─────────────────────────────────────────────
// Leaf — primitive value chip
// ─────────────────────────────────────────────

class _PrimitiveChip extends StatelessWidget {
  final String text;
  final Color color;

  const _PrimitiveChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: color,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Expandable node — object or array
// ─────────────────────────────────────────────

class _ExpandableNode extends StatefulWidget {
  // Accepts either JsonArray or JsonObject (both are JsonValue)
  final JsonValue value;
  final int depth;
  final int autoExpandDepth;

  const _ExpandableNode({
    required this.value,
    required this.depth,
    required this.autoExpandDepth,
  });

  @override
  State<_ExpandableNode> createState() => _ExpandableNodeState();
}

class _ExpandableNodeState extends State<_ExpandableNode> {
  late bool _expanded;

  // Computed once from the sealed value
  late final bool _isArray;
  late final int _length;
  late final Iterable<MapEntry<String, JsonValue>> _entries;

  @override
  void initState() {
    super.initState();
    _expanded = widget.depth < widget.autoExpandDepth;

    switch (widget.value) {
      case JsonArray v:
        _isArray = true;
        _length = v.length;
        // index as string key — matches React's `data.entries()`
        _entries = v.items.asMap().entries.map(
              (e) => MapEntry(e.key.toString(), e.value),
            );
      case JsonObject v:
        _isArray = false;
        _length = v.length;
        _entries = v.fields.entries;
      default:
        // unreachable — _ExpandableNode is only created for Array/Object
        _isArray = false;
        _length = 0;
        _entries = const [];
    }
  }

  String get _open => _isArray ? '[' : '{';
  String get _close => _isArray ? ']' : '}';

  @override
  Widget build(BuildContext context) {
    if (_length == 0) {
      return Text(
        '$_open$_close',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: _C.bracket_,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header row ──────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                turns: _expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(Icons.chevron_right, size: 14, color: _C.chevron_),
              ),
              const SizedBox(width: 2),
              Text(
                _open,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _C.bracket_,
                ),
              ),
              if (!_expanded) ...[
                Text(
                  ' $_length ${_isArray ? "items" : "keys"} ',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: _C.chevron_,
                  ),
                ),
                Text(
                  _close,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _C.bracket_,
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Children ────────────────────────────────
        if (_expanded) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Vertical indent guide line
                const SizedBox(width: 7),
                Container(width: 1, color: _C.indent_),
                const SizedBox(width: 8),

                // Entries
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, entry) in _entries.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Key
                            Text(
                              '${entry.key}: ',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: _C.key_,
                              ),
                            ),
                            // Value (recursive)
                            _JsonNode(
                              value: entry.value,
                              depth: widget.depth + 1,
                              autoExpandDepth: widget.autoExpandDepth,
                            ),
                            // Trailing comma
                            if (i < _length - 1)
                              const Text(
                                ',',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: _C.chevron_,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Closing bracket
          Text(
            _close,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: _C.bracket_,
            ),
          ),
        ],
      ],
    );
  }
}
