import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/domain/performance_notifier.dart';

/// Screen that shows aggregate query performance statistics.
///
/// Displays four summary cards (total fetches, avg latency, error rate, unique
/// keys) and a sortable data table with one row per query key.
class PerformanceScreen extends StatefulWidget {
  /// Creates the performance screen.
  const PerformanceScreen({super.key, required this.notifier});

  /// Notifier providing accumulated performance data.
  final PerformanceNotifier notifier;

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  SortField _sortField = SortField.fetches;
  bool _sortAscending = false;

  void _setSort(SortField field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.notifier,
      builder: (context, _) {
        final n = widget.notifier;
        var rows = n.sortedEntries(_sortField);
        if (_sortAscending) rows = rows.reversed.toList(growable: false);

        return Column(
          children: <Widget>[
            // ── Summary cards ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  _SummaryCard(
                    label: 'Total Fetches',
                    value: '${n.totalFetches}',
                  ),
                  const SizedBox(width: 8),
                  _SummaryCard(
                    label: 'Avg Latency',
                    value: '${n.overallAvgDurationMs.toStringAsFixed(0)} ms',
                  ),
                  const SizedBox(width: 8),
                  _SummaryCard(
                    label: 'Error Rate',
                    value: '${(n.overallErrorRate * 100).toStringAsFixed(1)}%',
                    valueColor: n.overallErrorRate > 0.1 ? Colors.red : null,
                  ),
                  const SizedBox(width: 8),
                  _SummaryCard(
                    label: 'Unique Keys',
                    value: '${n.uniqueKeyCount}',
                  ),
                ],
              ),
            ),
            // ── Clear button ────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  onPressed: n.clear,
                  icon: const Icon(Icons.delete_sweep, size: 16),
                  label: const Text('Clear stats'),
                ),
              ),
            ),
            // ── Data table ──────────────────────────────────────────────
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: Text(
                        'No data yet.\nFetch some queries to see stats.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: _sortField.index,
                          sortAscending: _sortAscending,
                          columns: <DataColumn>[
                            const DataColumn(label: Text('Query Key')),
                            DataColumn(
                              label: const Text('Fetches'),
                              numeric: true,
                              onSort: (_, __) => _setSort(SortField.fetches),
                            ),
                            DataColumn(
                              label: const Text('Avg ms'),
                              numeric: true,
                              onSort: (_, __) =>
                                  _setSort(SortField.avgDuration),
                            ),
                            DataColumn(
                              label: const Text('Errors'),
                              numeric: true,
                              onSort: (_, __) => _setSort(SortField.errors),
                            ),
                            DataColumn(
                              label: const Text('Last Active'),
                              onSort: (_, __) => _setSort(SortField.lastActive),
                            ),
                          ],
                          rows: rows.map(_buildRow).toList(growable: false),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  DataRow _buildRow(QueryStats s) {
    final lastActive = s.lastFetchedAtMs != null
        ? _fmtTime(DateTime.fromMillisecondsSinceEpoch(s.lastFetchedAtMs!))
        : '—';
    return DataRow(
      cells: <DataCell>[
        DataCell(
          Text(
            s.key,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(Text('${s.fetches}')),
        DataCell(Text(s.avgDurationMs.toStringAsFixed(0))),
        DataCell(
          Text(
            '${s.errors}',
            style: TextStyle(
              color: s.errors > 0 ? Colors.red : null,
              fontWeight: s.errors > 0 ? FontWeight.w600 : null,
            ),
          ),
        ),
        DataCell(
          Text(
            lastActive,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  String _fmtTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
