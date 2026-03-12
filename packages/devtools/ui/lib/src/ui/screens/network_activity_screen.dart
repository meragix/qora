import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/domain/network_activity_notifier.dart';

/// Screen that monitors query fetch activity in real-time.
///
/// Shows in-flight fetches (currently loading), recently completed fetches,
/// and aggregate statistics (total requests, average duration, error rate).
class NetworkActivityScreen extends StatelessWidget {
  /// Creates the network activity screen.
  const NetworkActivityScreen({super.key, required this.notifier});

  /// Notifier providing real-time fetch activity.
  final NetworkActivityNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notifier,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Stats strip ──────────────────────────────────────────────
            _StatsStrip(notifier: notifier),
            const Divider(height: 1),
            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: <Widget>[
                  _SectionHeader(
                    title: 'ACTIVE FETCHES',
                    badge: notifier.activeFetches.length,
                  ),
                  if (notifier.activeFetches.isEmpty)
                    const _EmptyHint(text: 'No queries currently fetching.')
                  else
                    ...notifier.activeFetches.map(
                      (r) => _ActiveFetchTile(record: r),
                    ),
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: 'RECENT FETCHES',
                    badge: notifier.recentFetches.length,
                    trailing: TextButton(
                      onPressed: notifier.clear,
                      child: const Text('Clear'),
                    ),
                  ),
                  if (notifier.recentFetches.isEmpty)
                    const _EmptyHint(text: 'No completed fetches yet.')
                  else
                    ...notifier.recentFetches.map(
                      (r) => _RecentFetchTile(record: r),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Stats strip ───────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.notifier});

  final NetworkActivityNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final avgMs = notifier.avgDurationMs;
    final errPct = (notifier.errorRate * 100).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          _StatCard(label: 'Total', value: '${notifier.totalRequests}'),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Avg duration',
            value: '${avgMs.toStringAsFixed(0)} ms',
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Error rate',
            value: '$errPct%',
            valueColor: notifier.errorRate > 0.1 ? Colors.red : null,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.badge,
    this.trailing,
  });

  final String title;
  final int badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ── Active fetch tile ─────────────────────────────────────────────────────────

class _ActiveFetchTile extends StatelessWidget {
  const _ActiveFetchTile({required this.record});

  final FetchRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                record.key,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent fetch tile ─────────────────────────────────────────────────────────

class _RecentFetchTile extends StatelessWidget {
  const _RecentFetchTile({required this.record});

  final FetchRecord record;

  @override
  Widget build(BuildContext context) {
    final isError = record.status == 'error';
    final (bg, fg) = isError
        ? (const Color(0xFFFEE2E2), const Color(0xFFB91C1C))
        : (const Color(0xFFDCFCE7), const Color(0xFF15803D));
    final durationLabel =
        record.durationMs != null ? '${record.durationMs} ms' : '—';
    final sizeLabel =
        record.approxBytes != null ? _formatBytes(record.approxBytes!) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                record.key,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (sizeLabel.isNotEmpty)
              Text(
                sizeLabel,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            const SizedBox(width: 8),
            Text(
              durationLabel,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                record.status ?? '—',
                style: TextStyle(
                  color: fg,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ── Empty hint ────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }
}
