import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/timeline_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Timeline tab — column 3, first tab of the Mutations panel.
///
/// Shows all [TimelineEvent]s in reverse-chronological order with a filter
/// input, pause toggle, and clear button. Reads [TimelineNotifier] from the
/// widget tree.
class TimelineTab extends StatelessWidget {
  const TimelineTab({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<TimelineNotifier>();
    final events = notifier.filteredEvents;

    return ColoredBox(
      color: DevtoolsColors.background,
      child: Column(children: [
        // ── Toolbar ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            Text(
              'TIMELINE (${events.length} EVENTS)',
              style: const TextStyle(
                color: DevtoolsColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            // ── Filter input ───────────────────────────────────────
            // SizedBox(
            //   width: 90,
            //   height: 26,
            //   child: TextField(
            //     onChanged: notifier.setFilter,
            //     style: const TextStyle(
            //       color: DevtoolsColors.textPrimary,
            //       fontSize: 11,
            //     ),
            //     decoration: InputDecoration(
            //       hintText: 'Filter…',
            //       hintStyle: const TextStyle(
            //         color: DevtoolsColors.textMuted,
            //         fontSize: 11,
            //       ),
            //       prefixIcon: const Icon(
            //         Icons.filter_list_rounded,
            //         size: 12,
            //         color: DevtoolsColors.textMuted,
            //       ),
            //       filled: true,
            //       fillColor: DevtoolsColors.inputBackground,
            //       border: OutlineInputBorder(
            //         borderRadius: BorderRadius.circular(4),
            //         borderSide: BorderSide.none,
            //       ),
            //       contentPadding: EdgeInsets.zero,
            //     ),
            //   ),
            // ),
            // const SizedBox(width: 6),
            // ── Pause / Resume ─────────────────────────────────────
            _ToolbarChip(
              label: notifier.paused ? 'Resume' : 'Pause',
              icon: notifier.paused ? LucideIcons.pause : LucideIcons.play,
              onTap: notifier.togglePause,
              backgroundColor: notifier.paused ? DevtoolsColors.statusStale : null,
            ),
            const SizedBox(width: 4),
            // Clear
            _ToolbarChip(label: 'Clear', icon: LucideIcons.trash2, onTap: notifier.clear),
          ]),
        ),
        // ── List ───────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: events.length,
            itemBuilder: (context, i) => TimelineEventRow(event: events[i]),
          ),
        ),
      ]),
    );
  }
}

// ── Toolbar chip ─────────────────────────────────────────────────────────────

class _ToolbarChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;

  const _ToolbarChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor ?? DevtoolsColors.inputBackground,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: DevtoolsColors.buttonText,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Event row ────────────────────────────────────────────────────────────────

/// Single row in the timeline list — coloured icon + event type + key + timestamp.
class TimelineEventRow extends StatelessWidget {
  final TimelineEvent event;

  const TimelineEventRow({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconForType(event.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.type.displayName,
                style: const TextStyle(
                  color: DevtoolsColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (event.key != null)
                Text(
                  event.key!,
                  style: const TextStyle(
                    color: DevtoolsColors.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        ),
        Text(
          _fmtTime(event.timestamp),
          style: const TextStyle(
            color: DevtoolsColors.textMuted,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
      ]),
    );
  }

  (IconData, Color) _iconForType(TimelineEventType t) => switch (t) {
        TimelineEventType.optimisticUpdate => (Icons.auto_fix_high, const Color(0xFFF59E0B)),
        TimelineEventType.mutationStarted => (Icons.play_arrow_rounded, const Color(0xFF8B5CF6)),
        TimelineEventType.mutationSuccess => (Icons.check_circle_outline, const Color(0xFF22C55E)),
        TimelineEventType.mutationError => (Icons.error_outline, const Color(0xFFEF4444)),
        TimelineEventType.fetchStarted => (Icons.download_rounded, const Color(0xFF3B82F6)),
        TimelineEventType.fetchError => (Icons.cloud_off_rounded, const Color(0xFFEF4444)),
        TimelineEventType.queryCreated => (Icons.add_circle_outline, const Color(0xFF22C55E)),
        TimelineEventType.cacheCleared => (Icons.delete_sweep_rounded, const Color(0xFF94A3B8)),
        TimelineEventType.queryCancelled => (Icons.cancel_outlined, const Color(0xFFF97316)),
      };

  String _fmtTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}.'
      '${dt.millisecond.toString().padLeft(3, '0')}';
}
