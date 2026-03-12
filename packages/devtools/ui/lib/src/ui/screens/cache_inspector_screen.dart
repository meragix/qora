import 'package:flutter/material.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/queries_notifier.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';
import 'package:qora_devtools_ui/src/domain/usecases/fetch_large_payload.dart';
import 'package:qora_devtools_ui/src/domain/usecases/refetch_query.dart';
import 'package:qora_devtools_ui/src/ui/state/cache_controller.dart';
import 'package:qora_devtools_ui/src/ui/widgets/query_row.dart';

/// Screen for inspecting the current cache — queries, their status, data,
/// and available actions (Refetch / Invalidate).
///
/// The query list updates in real-time via [QueriesNotifier] (driven by live
/// [QueryEvent]s) and can be fully re-synced at any time with the Refresh
/// button, which fetches a new [CacheSnapshot].
class CacheInspectorScreen extends StatefulWidget {
  /// Creates cache inspector screen.
  const CacheInspectorScreen({
    super.key,
    required this.controller,
    required this.queriesNotifier,
    required this.refetch,
    required this.fetchLargePayload,
    required this.repository,
  });

  /// Cache state controller (snapshot + live subscription).
  final CacheController controller;

  /// Live query list notifier.
  final QueriesNotifier queriesNotifier;

  /// Use-case for refetching a query.
  final RefetchQueryUseCase refetch;

  /// Use-case for loading large payloads on demand.
  final FetchLargePayloadUseCase fetchLargePayload;

  /// Repository used to dispatch invalidate commands.
  final EventRepository repository;

  @override
  State<CacheInspectorScreen> createState() => _CacheInspectorScreenState();
}

class _CacheInspectorScreenState extends State<CacheInspectorScreen> {
  String _filter = '';

  Future<void> _invalidate(String key) async {
    await widget.repository.sendCommand(InvalidateCommand(queryKey: key));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // ── Toolbar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _filter = v),
                  decoration: const InputDecoration(
                    hintText: 'Filter by key…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) => IconButton(
                  tooltip: 'Refresh snapshot',
                  onPressed: widget.controller.isLoading
                      ? null
                      : widget.controller.refresh,
                  icon: widget.controller.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ),
            ],
          ),
        ),
        // ── Summary strip ──────────────────────────────────────────────
        AnimatedBuilder(
          animation: widget.queriesNotifier,
          builder: (context, _) {
            final total = widget.queriesNotifier.queryList.length;
            final active = widget.queriesNotifier.activeQueryCount;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: <Widget>[
                  _SummaryChip(label: '$total queries'),
                  const SizedBox(width: 8),
                  _SummaryChip(label: '$active active'),
                ],
              ),
            );
          },
        ),
        // ── Error banner ───────────────────────────────────────────────
        AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            if (widget.controller.error case final err?) {
              return Container(
                width: double.infinity,
                color: Colors.red.shade50,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  'Error: $err',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        // ── Query list ─────────────────────────────────────────────────
        Expanded(
          child: AnimatedBuilder(
            animation: widget.queriesNotifier,
            builder: (context, _) {
              final queries = widget.queriesNotifier.queryList
                  .where(
                    (q) =>
                        _filter.isEmpty ||
                        q.key.toLowerCase().contains(_filter.toLowerCase()),
                  )
                  .toList(growable: false);

              if (queries.isEmpty) {
                return Center(
                  child: Text(
                    _filter.isEmpty
                        ? 'No queries yet.\nPress Refresh or wait for live updates.'
                        : 'No queries match "$_filter".',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: queries.length,
                itemBuilder: (context, i) {
                  final q = queries[i];
                  return QueryRow(
                    key: ValueKey(q.key),
                    snapshot: q,
                    refetch: widget.refetch,
                    invalidate: _invalidate,
                    fetchLargePayload: widget.fetchLargePayload,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Summary chip ──────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
