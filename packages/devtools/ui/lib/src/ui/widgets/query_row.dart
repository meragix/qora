import 'package:flutter/material.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/usecases/fetch_large_payload.dart';
import 'package:qora_devtools_ui/src/domain/usecases/refetch_query.dart';
import 'package:qora_devtools_ui/src/ui/widgets/json_tree_viewer.dart';

/// A single row in the Query Inspector list.
///
/// Renders the query key as breadcrumb chips, a colour-coded status badge,
/// payload size, last-updated timestamp, and Refetch / Invalidate action
/// buttons.  Tapping the row expands an inline [JsonTreeViewer] or triggers
/// lazy payload loading for large payloads.
class QueryRow extends StatefulWidget {
  /// Creates a query row.
  const QueryRow({
    super.key,
    required this.snapshot,
    required this.refetch,
    required this.invalidate,
    required this.fetchLargePayload,
  });

  /// The query snapshot to display.
  final QuerySnapshot snapshot;

  /// Use-case invoked when the Refetch button is pressed.
  final RefetchQueryUseCase refetch;

  /// Called with the query key when the Invalidate button is pressed.
  final Future<void> Function(String key) invalidate;

  /// Use-case used to load large payloads on demand.
  final FetchLargePayloadUseCase fetchLargePayload;

  @override
  State<QueryRow> createState() => _QueryRowState();
}

class _QueryRowState extends State<QueryRow> {
  bool _expanded = false;
  bool _loadingData = false;
  Object? _loadedData;
  String? _loadError;

  Future<void> _refetch() async {
    await widget.refetch(widget.snapshot.key);
  }

  Future<void> _invalidate() async {
    await widget.invalidate(widget.snapshot.key);
  }

  Future<void> _loadPayload() async {
    final payloadId = widget.snapshot.payloadId;
    final totalChunks = widget.snapshot.totalChunks;
    if (payloadId == null || totalChunks == null) return;

    setState(() {
      _loadingData = true;
      _loadError = null;
    });
    try {
      final data = await widget.fetchLargePayload(
        payloadId: payloadId,
        totalChunks: totalChunks,
      );
      setState(() {
        _loadedData = data;
        _loadingData = false;
      });
    } catch (e) {
      setState(() {
        _loadError = '$e';
        _loadingData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.snapshot;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Header row ────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: <Widget>[
                  Icon(
                    _expanded
                        ? Icons.arrow_drop_down
                        : Icons.arrow_right,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: _KeyBreadcrumb(key: ValueKey(q.key), queryKey: q.key)),
                  const SizedBox(width: 8),
                  _StatusBadge(status: q.status),
                  const SizedBox(width: 8),
                  if (q.summary != null) _SizePill(summary: q.summary!),
                  const SizedBox(width: 8),
                  _TimestampLabel(ms: q.updatedAtMs),
                ],
              ),
            ),
          ),
          // ── Expanded section ──────────────────────────────────────────
          if (_expanded) ...<Widget>[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Action buttons
                  Row(
                    children: <Widget>[
                      _ActionButton(
                        label: 'Refetch',
                        icon: Icons.refresh,
                        onPressed: _refetch,
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        label: 'Invalidate',
                        icon: Icons.block,
                        onPressed: _invalidate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Data section
                  _buildDataSection(q),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataSection(QuerySnapshot q) {
    if (q.hasLargePayload) {
      if (_loadingData) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      if (_loadError != null) {
        return Text(
          'Load failed: $_loadError',
          style: const TextStyle(color: Colors.red, fontSize: 12),
        );
      }
      if (_loadedData != null) {
        return JsonTreeViewer(value: _loadedData);
      }
      return TextButton.icon(
        onPressed: _loadPayload,
        icon: const Icon(Icons.download, size: 14),
        label: const Text('Load data'),
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      );
    }

    if (q.data == null) {
      return const Text(
        'No data',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }

    return JsonTreeViewer(value: q.data);
  }
}

// ── Key breadcrumb ─────────────────────────────────────────────────────────────

class _KeyBreadcrumb extends StatelessWidget {
  const _KeyBreadcrumb({super.key, required this.queryKey});

  final String queryKey;

  @override
  Widget build(BuildContext context) {
    final segments = _splitKey(queryKey);
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: segments
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                s,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  List<String> _splitKey(String key) {
    final stripped = key.replaceAll(RegExp(r'[\[\]"]'), '');
    return stripped
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}

// ── Status badge ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color) _colors(String s) => switch (s) {
        'loading' || 'refreshing' => (
            const Color(0xFFDBEAFE),
            const Color(0xFF1D4ED8)
          ),
        'success' => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
        'error' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
        'stale' => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
        _ => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
      };
}

// ── Size pill ──────────────────────────────────────────────────────────────────

class _SizePill extends StatelessWidget {
  const _SizePill({required this.summary});

  final Map<String, Object?> summary;

  @override
  Widget build(BuildContext context) {
    final bytes = summary['approxBytes'] as int?;
    if (bytes == null) return const SizedBox.shrink();

    final label = bytes < 1024
        ? '${bytes}B'
        : bytes < 1024 * 1024
            ? '${(bytes / 1024).toStringAsFixed(1)}KB'
            : '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';

    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 10,
        fontFamily: 'monospace',
      ),
    );
  }
}

// ── Timestamp ─────────────────────────────────────────────────────────────────

class _TimestampLabel extends StatelessWidget {
  const _TimestampLabel({required this.ms});

  final int ms;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final label =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFCBD5E1),
        fontSize: 10,
        fontFamily: 'monospace',
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        textStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
