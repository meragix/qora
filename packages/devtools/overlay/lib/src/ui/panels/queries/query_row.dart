import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qora_devtools_overlay/src/ui/panels/shared/breadcrumb_key.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';
import 'package:qora_devtools_overlay/utils/query_utils.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Single row in the Queries panel list.
///
/// Displays the [QueryEvent.key] as a [BreadcrumbKey] breadcrumb on the left
/// and the current status badge on the right.
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
    print('Building QueryRow for ${query.key} with status ${query.status}'); // Debug print
    print(
        'QueryEvent details: eventId=${query.eventId}, totalChunks=${query.totalChunks}, data=${query.data}, fetchDurationMs=${query.fetchDurationMs}'); // Debug print
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      margin: const EdgeInsets.only(top: 6),
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
    return Row(
      children: [
        _MetaChip('${query.totalChunks}', icon: LucideIcons.usersRound), // todo: implement observers
        const SizedBox(width: 10),
        _MetaChip('stale: ${query.data}', icon: LucideIcons.clock),
        const SizedBox(width: 10),
        _MetaChip('gc: ${query.fetchDurationMs}', icon: LucideIcons.trash2),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;
  final IconData icon;

  const _MetaChip(this.text, {this.icon = Icons.info_outline});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(text, style: DevtoolsTypography.queryMeta),
      ],
    );
  }
}
