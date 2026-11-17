import 'package:flutter/material.dart';
import 'package:qora/qora.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/queue/queue_status_color.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

/// One call of the mutation queue: key, status, attempts, scope, and the
/// last error when an attempt failed.
class QueueRow extends StatelessWidget {
  const QueueRow({
    super.key,
    required this.entry,
    required this.onTap,
    this.isSelected = false,
  });

  final QueuedMutation entry;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = queueStatusColor(entry.status);
    final error = entry.lastError;
    return InkWell(
      onTap: onTap,
      hoverColor: DevtoolsColors.rowHover,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? DevtoolsColors.rowSelected : Colors.transparent,
          border: Border(
            left: isSelected
                ? const BorderSide(color: DevtoolsColors.accent, width: 2)
                : BorderSide.none,
          ),
        ),
        padding: [8, 10].edgeInsetsVH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: 6.edgeInsetsT,
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DevtoolsTypography.queryKey,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      entry.status.name,
                      '${entry.attempts} '
                          '${entry.attempts == 1 ? 'attempt' : 'attempts'}',
                      entry.scope ?? 'no scope',
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DevtoolsTypography.queryMeta,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$error',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DevtoolsTypography.queryMeta
                          .copyWith(color: DevtoolsColors.red400),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
