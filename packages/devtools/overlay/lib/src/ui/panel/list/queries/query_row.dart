import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';
import 'package:qora_devtools_overlay/utils/query_utils.dart' show formatQueryKey, formatQueryTime;
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class QueryRow extends StatelessWidget {
  final QueryEvent query;
  final VoidCallback onTap;
  final bool isActive;

  const QueryRow({
    super.key,
    required this.query,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: DevtoolsColors.rowHover,
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? DevtoolsColors.rowSelected : Colors.transparent,
          border: Border(
            left: isActive
                ? BorderSide(
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
            _StatusDot(status: _queryStatus(query)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatQueryKey(query.key),
                    style: DevtoolsTypography.queryKey,
                  ),
                  const SizedBox(height: 4),
                  _MetaRow(query: query),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _QueryStatus _queryStatus(QueryEvent q) {
    if (q.status == 'loading') return _QueryStatus.fetching;
    if (q.status == 'error') return _QueryStatus.error;
    if (q.status == 'success') return _QueryStatus.fresh;
    return _QueryStatus.stale;
  }
}

// ── Status enum ──────────────────────────────────────────────────────────────

enum _QueryStatus {
  fetching(DevtoolsColors.statusFetching),
  error(DevtoolsColors.statusError),
  fresh(DevtoolsColors.statusFresh),
  stale(DevtoolsColors.statusStale);

  const _QueryStatus(this.color);
  final Color color;
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final _QueryStatus status;

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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.query});

  final QueryEvent query;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final staleTimeLeft = query.staleTimeMs ?? 0 - now;
    final gcTimeLeft = query.gcTimeMs ?? 0 - now;

    return Wrap(
      spacing: 10,
      runSpacing: 2,
      children: [
        _MetaChip(
          label: '',
          value: '${query.observerCount}',
          icon: LucideIcons.userRound,
        ),
        _MetaChip(
          label: 'stale: ',
          value: formatQueryTime(staleTimeLeft),
          icon: LucideIcons.clock,
          color: staleTimeLeft <= 0 ? DevtoolsColors.orange400 : null,
        ),
        _MetaChip(
          label: 'gc: ',
          value: formatQueryTime(gcTimeLeft),
          icon: LucideIcons.trash2,
          color: gcTimeLeft <= 0 ? DevtoolsColors.red400 : null,
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _MetaChip({
    required this.label,
    required this.value,
    this.icon = Icons.info_outline,
    this.color = DevtoolsColors.textDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: DevtoolsColors.textDisabled),
        const SizedBox(width: 3),
        Text.rich(
          TextSpan(
            style: DevtoolsTypography.queryMeta,
            children: [
              TextSpan(text: label),
              TextSpan(
                text: value,
                style: DevtoolsTypography.queryMeta.copyWith(color: color),
              )
            ],
          ),
        ),
      ],
    );
  }
}
