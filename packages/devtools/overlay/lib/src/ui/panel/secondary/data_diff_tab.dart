import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Data Diff tab — column 3, third tab of the Mutations panel.
///
/// Shows a before/after comparison for the selected mutation:
/// - **Before** — variables submitted to the mutator
/// - **After**  — result returned from the server (or error on failure)
///
/// When a rollback context is present (optimistic update), it is shown in the
/// before column, indicating the pre-optimistic cache snapshot.
class DataDiffTab extends StatelessWidget {
  const DataDiffTab({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MutationInspectorNotifier>();
    final selected = notifier.selected;

    if (selected == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              LucideIcons.fileDiff,
              color: DevtoolsColors.textMuted,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              'Select a mutation to compare data',
              style: TextStyle(
                color: DevtoolsColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final isSettled = selected.type == MutationEventType.settled;
    final isSuccess = isSettled && (selected.success ?? false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Before column ───────────────────────────────────────────────
        Expanded(
          child: _DiffColumn(
            label: 'BEFORE',
            labelColor: const Color(0xFF64748B),
            value: selected.variables,
            emptyText: 'No variables sent',
          ),
        ),
        const VerticalDivider(width: 1, color: Color(0xFF1E293B)),
        // ── After column ────────────────────────────────────────────────
        Expanded(
          child: _DiffColumn(
            label: isSettled
                ? (isSuccess ? 'AFTER (success)' : 'AFTER (error)')
                : 'AFTER (pending)',
            labelColor: isSettled
                ? (isSuccess
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444))
                : const Color(0xFF64748B),
            value: selected.result,
            emptyText: isSettled ? 'No result data' : 'Pending…',
          ),
        ),
      ],
    );
  }
}

// ── Diff column ───────────────────────────────────────────────────────────────

class _DiffColumn extends StatelessWidget {
  const _DiffColumn({
    required this.label,
    required this.labelColor,
    required this.value,
    required this.emptyText,
  });

  final String label;
  final Color labelColor;
  final Object? value;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: labelColor.withValues(alpha: 0.1),
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: value != null
                ? _JsonValue(value: value)
                : Text(
                    emptyText,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Minimal JSON renderer (overlay dark-themed) ───────────────────────────────

class _JsonValue extends StatefulWidget {
  const _JsonValue({required this.value});
  final Object? value;

  @override
  State<_JsonValue> createState() => _JsonValueState();
}

class _JsonValueState extends State<_JsonValue> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    if (v is Map) return _buildObject(v);
    if (v is List) return _buildArray(v);
    return _buildLeaf(v);
  }

  Widget _buildObject(Map<dynamic, dynamic> map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? '{' : '{…}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: map.entries
                  .map(
                    (e) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '"${e.key}": ',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Expanded(child: _JsonValue(value: e.value)),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }

  Widget _buildArray(List<dynamic> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? '[${list.length}]' : '[…${list.length}]',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: list
                  .asMap()
                  .entries
                  .map((e) => _JsonValue(value: e.value))
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }

  Widget _buildLeaf(Object? v) {
    final (text, color) = switch (v) {
      null => ('null', const Color(0xFF94A3B8)),
      bool b => ('$b', const Color(0xFFF59E0B)),
      num n => ('$n', const Color(0xFF60A5FA)),
      String s => ('"$s"', const Color(0xFF34D399)),
      _ => ('$v', const Color(0xFFE2E8F0)),
    };
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontFamily: 'monospace',
      ),
    );
  }
}
