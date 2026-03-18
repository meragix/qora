import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/utils/copy_to_clipboard.dart';

/// Recursively renders a JSON value as an interactive expand/collapse tree.
///
/// Visual style matches the in-app overlay's JSON viewer: animated chevron,
/// vertical indent guide lines, and syntax-coloured primitives. Theming adapts
/// automatically to the host [ThemeData] (light DevTools / dark DevTools).
///
/// Hovering over the widget reveals a **copy** button that serialises the
/// full JSON value to the clipboard (pretty-printed, 2-space indent).
///
/// Accepts any [Object?] — the value is converted to a [JsonValue] tree via
/// [JsonValue.fromDynamic] at the root.
class JsonTreeViewer extends StatefulWidget {
  const JsonTreeViewer({
    super.key,
    required this.value,
    this.autoExpandDepth = 2,
  });

  /// The raw JSON value to render (Map, List, String, num, bool, or null).
  final Object? value;

  /// How many nesting levels are expanded on first render.
  final int autoExpandDepth;

  @override
  State<JsonTreeViewer> createState() => _JsonTreeViewerState();
}

class _JsonTreeViewerState extends State<JsonTreeViewer> {
  bool _hovered = false;

  static const _encoder = JsonEncoder.withIndent('  ');

  void _copy(JsonValue jsonValue) {
    final obj = _toObject(jsonValue);
    unawaited(
      copyToClipboard(
        _encoder.convert(obj),
        successMessage: 'JSON copied to clipboard',
      ),
    );
  }

  /// Converts a [JsonValue] tree back to plain Dart objects for JSON encoding.
  Object? _toObject(JsonValue value) => switch (value) {
        JsonNull() => null,
        JsonBool v => v.value,
        JsonNumber v => v.value,
        JsonString v => v.value,
        JsonArray v => v.items.map(_toObject).toList(),
        JsonObject v => v.fields.map((k, val) => MapEntry(k, _toObject(val))),
      };

  @override
  Widget build(BuildContext context) {
    final jsonValue = JsonValue.fromDynamic(widget.value);
    final colors = _JsonSyntaxColors.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: <Widget>[
          SelectionArea(
            child: Padding(
              padding: const EdgeInsets.all(denseSpacing),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _JsonNode(
                    value: jsonValue,
                    depth: 0,
                    autoExpandDepth: widget.autoExpandDepth,
                    colors: colors,
                  ),
                ),
              ),
            ),
          ),

          // ── Copy button — appears on hover ────────────────────────────────
          if (_hovered)
            Positioned(
              top: densePadding,
              right: densePadding,
              child: DevToolsButton(
                icon: Icons.copy_outlined,
                outlined: false,
                tooltip: 'Copy JSON',
                onPressed: () => _copy(jsonValue),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Syntax colour set ──────────────────────────────────────────────────────────

class _JsonSyntaxColors {
  const _JsonSyntaxColors({
    required this.null_,
    required this.string_,
    required this.number_,
    required this.bool_,
    required this.key_,
    required this.bracket_,
    required this.chevron_,
    required this.indent_,
  });

  final Color null_;
  final Color string_;
  final Color number_;
  final Color bool_;
  final Color key_;
  final Color bracket_;
  final Color chevron_;
  final Color indent_;

  /// Dark syntax colours — identical to the overlay palette (Zinc + Tailwind).
  static const _dark = _JsonSyntaxColors(
    null_: Color(0xFFC084FC), // purple-400
    string_: Color(0xFF4ADE80), // green-400
    number_: Color(0xFF60A5FA), // blue-400
    bool_: Color(0xFFFB923C), // orange-400
    key_: Color(0xFF22D3EE), // cyan-400
    bracket_: Color(0xFF71717A), // zinc-500
    chevron_: Color(0xFF71717A), // zinc-500
    indent_: Color(0xFF3F3F46), // zinc-700
  );

  /// Light syntax colours — VSCode JSON theme.
  static const _light = _JsonSyntaxColors(
    null_: Color(0xFF795E26),
    string_: Color(0xFF008000),
    number_: Color(0xFF098658),
    bool_: Color(0xFF0000FF),
    key_: Color(0xFFA31515),
    bracket_: Color(0xFF808080),
    chevron_: Color(0xFF808080),
    indent_: Color(0xFFCCCCCC),
  );

  static _JsonSyntaxColors of(BuildContext context) =>
      Theme.of(context).colorScheme.brightness == Brightness.dark
          ? _dark
          : _light;
}

// ── Node dispatcher ────────────────────────────────────────────────────────────

class _JsonNode extends StatelessWidget {
  const _JsonNode({
    required this.value,
    required this.depth,
    required this.autoExpandDepth,
    required this.colors,
  });

  final JsonValue value;
  final int depth;
  final int autoExpandDepth;
  final _JsonSyntaxColors colors;

  @override
  Widget build(BuildContext context) {
    final font = Theme.of(context).fixedFontStyle;
    return switch (value) {
      JsonNull() => Text('null', style: font.copyWith(color: colors.null_)),
      JsonBool v =>
        Text(v.value.toString(), style: font.copyWith(color: colors.bool_)),
      JsonNumber v =>
        Text(v.value.toString(), style: font.copyWith(color: colors.number_)),
      JsonString v =>
        Text('"${v.value}"', style: font.copyWith(color: colors.string_)),
      JsonArray _ || JsonObject _ => _ExpandableNode(
          value: value,
          depth: depth,
          autoExpandDepth: autoExpandDepth,
          colors: colors,
        ),
    };
  }
}

// ── Expandable node ────────────────────────────────────────────────────────────

class _ExpandableNode extends StatefulWidget {
  const _ExpandableNode({
    required this.value,
    required this.depth,
    required this.autoExpandDepth,
    required this.colors,
  });

  final JsonValue value; // JsonArray or JsonObject
  final int depth;
  final int autoExpandDepth;
  final _JsonSyntaxColors colors;

  @override
  State<_ExpandableNode> createState() => _ExpandableNodeState();
}

class _ExpandableNodeState extends State<_ExpandableNode> {
  late bool _expanded;
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
        _entries = v.items
            .asMap()
            .entries
            .map((e) => MapEntry(e.key.toString(), e.value));
      case JsonObject v:
        _isArray = false;
        _length = v.length;
        _entries = v.fields.entries;
      default:
        _isArray = false;
        _length = 0;
        _entries = const [];
    }
  }

  String get _open => _isArray ? '[' : '{';
  String get _close => _isArray ? ']' : '}';

  @override
  Widget build(BuildContext context) {
    final font = Theme.of(context).fixedFontStyle;
    final colors = widget.colors;

    if (_length == 0) {
      return Text('$_open$_close',
          style: font.copyWith(color: colors.bracket_));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // ── Header row ────────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedRotation(
                turns: _expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child:
                    Icon(Icons.chevron_right, size: 14, color: colors.chevron_),
              ),
              const SizedBox(width: 2),
              Text(_open, style: font.copyWith(color: colors.bracket_)),
              if (!_expanded) ...<Widget>[
                Text(
                  ' $_length ${_isArray ? "items" : "keys"} ',
                  style: font.copyWith(color: colors.bracket_, fontSize: 11),
                ),
                Text(_close, style: font.copyWith(color: colors.bracket_)),
              ],
            ],
          ),
        ),

        // ── Children ─────────────────────────────────────────────────────
        if (_expanded) ...<Widget>[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(width: 7),
                Container(width: 1, color: colors.indent_),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final (i, entry) in _entries.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${entry.key}: ',
                              style: font.copyWith(color: colors.key_),
                            ),
                            _JsonNode(
                              value: entry.value,
                              depth: widget.depth + 1,
                              autoExpandDepth: widget.autoExpandDepth,
                              colors: colors,
                            ),
                            if (i < _length - 1)
                              Text(',',
                                  style: font.copyWith(color: colors.bracket_)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Text(_close, style: font.copyWith(color: colors.bracket_)),
        ],
      ],
    );
  }
}
