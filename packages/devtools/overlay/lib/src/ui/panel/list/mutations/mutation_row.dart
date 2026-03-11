import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';
import 'package:qora_devtools_overlay/utils/query_utils.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class MutationRow extends StatelessWidget {
  final MutationEvent mutation;
  final VoidCallback onTap;
  final bool isSelected;

  const MutationRow({
    super.key,
    required this.mutation,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: DevtoolsColors.rowHover,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? DevtoolsColors.rowSelected : Colors.transparent,
          border: Border(
            left: isSelected
                ? const BorderSide(
                    color: DevtoolsColors.accent,
                    width: 2,
                  )
                : BorderSide.none,
          ),
        ),
        padding: [8, 10].edgeInsetsVH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusDot(status: _queryStatus(mutation)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mutation.key != '' ? formatQueryKey(mutation.key) : mutation.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DevtoolsTypography.queryKey,
                  ),
                  if (mutation.success ?? false)
                    Padding(
                      padding: 4.edgeInsetsT,
                      child: Row(
                        children: [
                          Icon(LucideIcons.zap, size: 13, color: DevtoolsColors.amber400),
                          const SizedBox(width: 3),
                          Text(
                            'Optimistic',
                            style: TextStyle(color: DevtoolsColors.amber400, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13, color: DevtoolsColors.textDisabled),
                        const SizedBox(width: 3),
                        Text(
                          formatTimeAgo(mutation.timestampMs),
                          style: const TextStyle(fontSize: 10, color: DevtoolsColors.textDisabled),
                        ),
                        if (mutation.timestampMs > 0) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Retries: 2',
                            style: const TextStyle(fontSize: 10, color: DevtoolsColors.orange400),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _MutationStatus _queryStatus(MutationEvent e) {
    if (e.type == MutationEventType.settled) {
      return (e.success ?? false) ? _MutationStatus.success : _MutationStatus.error;
    }
    return _MutationStatus.pending;
  }
}

// ── Status enum ──────────────────────────────────────────────────────────────

enum _MutationStatus {
  pending(DevtoolsColors.statusFetching),
  success(DevtoolsColors.statusFresh),
  error(DevtoolsColors.statusError);

  const _MutationStatus(this.color);
  final Color color;
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final _MutationStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: 6.edgeInsetsT,
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: status.color,
        shape: BoxShape.circle,
      ),
    );
  }
}
