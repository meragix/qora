import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

// Internal shared widgets for the query and mutation inspector panels.
// Not exported from the library barrel.

/// Labeled section block used in inspector detail panels.
///
/// Renders an uppercase section label above a [child] widget with consistent
/// spacing so all sections align visually across the inspector.
class InspectorSection extends StatelessWidget {
  final String label;
  final Widget child;
  final bool shwowDivider;

  const InspectorSection({
    super.key,
    required this.label,
    required this.child,
    this.shwowDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DevtoolsTypography.smallMuted.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: DevtoolsColors.textDisabled,
            ),
          ),
          const SizedBox(height: 8),
          child,
          const SizedBox(height: 10),
          if (shwowDivider) Divider(height: DevtoolsSpacing.borderWidth),
        ],
      ),
    );
  }
}

/// Key-value metadata row with a fixed-width label column.
class InspectorMetaRow extends StatelessWidget {
  final String label;
  final String value;

  const InspectorMetaRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: DevtoolsTypography.smallMuted),
          ),
          Expanded(
            child: Text(
              value,
              style: DevtoolsTypography.code,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small action button rendered inside inspector ACTIONS sections.
///
/// [accentColor] tints the background and icon — use it to colour-code
/// actions by severity (blue = safe, orange = warning, red = destructive).
class InspectorActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accentColor;

  const InspectorActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.accentColor,
  });

  @override
  State<InspectorActionButton> createState() => _InspectorActionButtonState();
}

class _InspectorActionButtonState extends State<InspectorActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? widget.accentColor?.withValues(alpha: 0.8) : widget.accentColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: 6.borderRadiusA,
          child: Padding(
            padding: [4, 8].edgeInsetsVH,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: DevtoolsTypography.smallMuted.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Formats a [DateTime] as `HH:mm:ss.mmm` for inspector metadata rows.
String fmtDateTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}:'
    '${dt.second.toString().padLeft(2, '0')}.'
    '${dt.millisecond.toString().padLeft(3, '0')}';
