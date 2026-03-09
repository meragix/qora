import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/timeline_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/utils/query_utils.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Timeline tab — column 3, first tab of the Mutations panel.
///
/// Shows all [TimelineEvent]s in reverse-chronological order with a filter
/// input, pause toggle, and clear button. Reads [TimelineNotifier] from the
/// widget tree.
class TimelineTab extends StatefulWidget {
  const TimelineTab({super.key});

  @override
  State<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<TimelineTab> {
  final _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<TimelineNotifier>();
    final events = notifier.filteredEvents;

    return ColoredBox(
      color: DevtoolsColors.background,
      child: Column(
        children: [
          // ── Toolbar ────────────────────────────────────────────────
          Container(
            padding: [6, 8].edgeInsetsVH,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DevtoolsColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'TIMELINE (${events.length} EVENTS)',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DevtoolsColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      height: 26,
                      child: TextField(
                        controller: _filterController,
                        onChanged: notifier.setFilter,
                        style: const TextStyle(
                          color: DevtoolsColors.textPrimary,
                          fontSize: 11,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Filter...',
                          hintStyle: const TextStyle(
                            color: DevtoolsColors.textMuted,
                            fontSize: 11,
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.listFilter,
                            size: 12,
                            color: DevtoolsColors.textDisabled,
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 0),
                          suffixIcon: notifier.filter.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _filterController.clear();
                                    notifier.setFilter('');
                                  },
                                  child: const Icon(
                                    LucideIcons.x,
                                    size: 12,
                                    color: DevtoolsColors.textDisabled,
                                  ),
                                )
                              : null,
                          suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 0),
                          filled: true,
                          fillColor: DevtoolsColors.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: 4.borderRadiusA,
                            borderSide: const BorderSide(color: DevtoolsColors.zinc700), // zinc-700
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: 4.borderRadiusA,
                            borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: 4.borderRadiusA,
                            borderSide: const BorderSide(color: DevtoolsColors.zinc600), // zinc-600
                          ),
                          contentPadding: 8.edgeInsetsH,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _IconButton(
                      icon: notifier.paused ? LucideIcons.pause : LucideIcons.play,
                      tooltip: notifier.paused ? 'Resume timeline' : 'Pause timeline',
                      isActive: notifier.paused,
                      color: const Color(0xFFFBBF24), // amber when toggled on
                      onTap: notifier.togglePause,
                    ),
                    const SizedBox(width: 4),
                    _IconButton(
                      icon: LucideIcons.trash2,
                      tooltip: 'Clear all',
                      onTap: notifier.clear,
                      color: const Color(0xFFF87171), // red tint when active
                    ),
                  ],
                )
              ],
            ),
          ),
          // ── List ───────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: events.length,
              itemBuilder: (context, i) => Column(
                children: [
                  Divider(height: DevtoolsSpacing.borderWidth),
                  TimelineEventRow(event: events[i]),
                  if (i < events.length - 1) const Divider(height: DevtoolsSpacing.borderWidth),
                ],
              ),
            ),
          ),
        ],
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
    return InkWell(
      onTap: () {},
      hoverColor: DevtoolsColors.background.withValues(alpha: 0.5),
      child: Padding(
        padding: [8, 16].edgeInsetsVH,
        child: Row(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      event.type.displayName,
                      style: const TextStyle(
                        color: DevtoolsColors.zinc300,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (event.duration != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${event.duration}ms)',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Color(0xFF71717A), // zinc-500
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (event.key != null)
                  Text(
                    formatQueryKey(event.key!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Color(0xFF71717A),
                    ),
                  ),
                Text(
                  fmtDateTime(event.timestamp),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Color(0xFF52525B), // zinc-600
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
      ),
    );
  }

  (IconData, Color) _iconForType(TimelineEventType t) => switch (t) {
        TimelineEventType.optimisticUpdate => (LucideIcons.zap, const Color(0xFFF59E0B)),
        TimelineEventType.mutationStarted => (LucideIcons.send, const Color(0xFF8B5CF6)),
        TimelineEventType.mutationSuccess => (LucideIcons.circleCheck, const Color(0xFF22C55E)),
        TimelineEventType.mutationError => (LucideIcons.circleX, const Color(0xFFEF4444)),
        TimelineEventType.fetchStarted => (LucideIcons.arrowDownToLine, const Color(0xFF3B82F6)),
        TimelineEventType.fetchSuccess => (LucideIcons.circleCheck, const Color(0xFF10B981)),
        TimelineEventType.fetchError => (LucideIcons.cloudOff, const Color(0xFFEF4444)),
        TimelineEventType.queryInvalidated => (LucideIcons.refreshCw, const Color(0xFFF59E0B)),
        TimelineEventType.queryCreated => (LucideIcons.circlePlus, const Color(0xFF22C55E)),
        TimelineEventType.cacheCleared => (LucideIcons.trash2, const Color(0xFF94A3B8)),
        TimelineEventType.queryCancelled => (LucideIcons.ban, const Color(0xFFF97316)),
      };

  // EventStyle getEventStyle(EventType type) {
  //   return switch (type) {
  //     EventType.queryCreated => (icon: Icons.add, color: const Color(0xFF22D3EE)), // cyan-400
  //     EventType.fetchStarted => (icon: Icons.play_arrow_rounded, color: const Color(0xFF60A5FA)), // blue-400
  //     EventType.fetchSuccess => (icon: Icons.check_circle_outline, color: const Color(0xFF4ADE80)), // green-400
  //     EventType.fetchError => (icon: Icons.cancel_outlined, color: const Color(0xFFF87171)), // red-400
  //     EventType.invalidated => (icon: Icons.refresh_rounded, color: const Color(0xFFFACC15)), // yellow-400
  //     EventType.garbageCollected => (icon: Icons.delete_outline, color: const Color(0xFFA1A1AA)), // zinc-400
  //     EventType.mutationStarted => (icon: Icons.send_rounded, color: const Color(0xFFC084FC)), // purple-400
  //     EventType.mutationSuccess => (icon: Icons.done_all_rounded, color: const Color(0xFF34D399)), // emerald-400
  //     EventType.mutationError => (icon: Icons.warning_amber_rounded, color: const Color(0xFFFB923C)), // orange-400
  //     EventType.optimisticUpdate => (icon: Icons.bolt_rounded, color: const Color(0xFFFBBF24)), // amber-400
  //   };
  // }

  String _fmtTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}.'
      '${dt.millisecond.toString().padLeft(3, '0')}';
}

class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final bool isActive;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? DevtoolsColors.zinc500;
    final bg = widget.isActive
        ? accent.withValues(alpha: 0.15)
        : _hovered
            ? DevtoolsColors.zinc800
            : DevtoolsColors.zinc900;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: widget.isActive ? Border.all(color: accent.withValues(alpha: 0.3), width: 1) : null,
            ),
            child: Icon(
              widget.icon,
              size: 13,
              color: widget.isActive
                  ? accent
                  : _hovered
                      ? const Color(0xFFD4D4D8) // zinc-200
                      : const Color(0xFF71717A), // zinc-500
            ),
          ),
        ),
      ),
    );
  }
}
