import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/queries_notifier.dart';
import 'package:qora_devtools_overlay/src/domain/query_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/queries/query_row.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/queries/query_search_bar.dart';
import 'package:qora_devtools_overlay/src/ui/shared/empty_state.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/shared/panel_section.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/utils/query_utils.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class QueriesTab extends StatefulWidget {
  final void Function(QueryEvent) onQueryTap;

  const QueriesTab({super.key, required this.onQueryTap});

  @override
  State<QueriesTab> createState() => _QueriesTabState();
}

class _QueriesTabState extends State<QueriesTab> {
  final TextEditingController _controller = TextEditingController();
  String _search = '';
  // Ticks every second to refresh stale / gc  countdowns.
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<QueryEvent> _filtered(List<QueryEvent> queries) {
    if (_search.isEmpty) return queries;
    return queries
        .where((q) => formatQueryKey(q.key).toLowerCase().contains(_search))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final queries = context.watch<QueriesNotifier>().queries;
    final selectedKey = context.watch<QueryInspectorNotifier>().selected?.key;

    if (queries.isEmpty) {
      return const EmptyState(message: 'No queries yet');
    }

    final filtered = _filtered(queries);

    return Column(
      children: [
        PanelSection(label: 'QUERIES (${filtered.length})'),
        QuerySearchBar(
          controller: _controller,
          onChanged: (s) => setState(() => _search = s.toLowerCase()),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: 32.edgeInsetsA,
            child: EmptyState(message: 'No queries match "$_search".'),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final query = filtered[i];
              return Column(
                children: [
                  Divider(height: DevtoolsSpacing.borderWidth),
                  QueryRow(
                    query: query,
                    onTap: () => widget.onQueryTap(query),
                    isSelected: selectedKey == query.key,
                  ),
                  if (i == filtered.length - 1)
                    Divider(height: DevtoolsSpacing.borderWidth),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
