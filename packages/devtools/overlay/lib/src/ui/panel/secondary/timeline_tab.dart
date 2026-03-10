import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/timeline_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/utils/query_utils.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

typedef EventStyle = ({IconData icon, Color color});

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
              itemCount: events.length,
              itemBuilder: (context, i) => Column(
                children: [
                  TimelineEventRow(event: events[i]),
                  const Divider(height: DevtoolsSpacing.borderWidth),
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
    final style = _getEventStyle(event.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        mouseCursor: SystemMouseCursors.text,
        hoverColor: DevtoolsColors.zinc900.withValues(alpha: 0.5),
        child: Padding(
          padding: [8, 16].edgeInsetsVH,
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(style.icon, size: 12, color: style.color),
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
                            color: DevtoolsColors.textDisabled,
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
                        color: DevtoolsColors.textDisabled,
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
      ),
    );
  }

  EventStyle _getEventStyle(TimelineEventType type) {
    return switch (type) {
      TimelineEventType.queryCreated => (icon: LucideIcons.plus, color: DevtoolsColors.cyan400),
      TimelineEventType.fetchStarted => (icon: LucideIcons.play, color: DevtoolsColors.blue400),
      TimelineEventType.fetchSuccess => (icon: LucideIcons.circleCheckBig, color: DevtoolsColors.green400),
      TimelineEventType.fetchError => (icon: LucideIcons.cloudOff, color: DevtoolsColors.red400),
      TimelineEventType.queryInvalidated => (icon: LucideIcons.refreshCcw, color: DevtoolsColors.yellow400),
      TimelineEventType.queryCancelled => (icon: LucideIcons.ban, color: DevtoolsColors.zinc400),
      TimelineEventType.cacheCleared => (icon: LucideIcons.trash2, color: const Color(0xFF94A3B8)),
      TimelineEventType.queryRemoved => (icon: LucideIcons.trash, color: DevtoolsColors.red400),
      TimelineEventType.queryMarkedStale => (icon: LucideIcons.clock, color: DevtoolsColors.yellow400),
      TimelineEventType.mutationStarted => (icon: LucideIcons.send, color: DevtoolsColors.purple400),
      TimelineEventType.mutationSuccess => (icon: LucideIcons.checkCheck, color: DevtoolsColors.emerald400),
      TimelineEventType.mutationError => (icon: LucideIcons.circleX, color: DevtoolsColors.red400),
      TimelineEventType.optimisticUpdate => (icon: LucideIcons.zap, color: DevtoolsColors.amber400),
    };
  }

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
