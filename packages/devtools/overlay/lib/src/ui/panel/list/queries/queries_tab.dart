import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/queries_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/queries/query_row.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/queries/query_search_bar.dart';
import 'package:qora_devtools_overlay/src/ui/shared/empty_state.dart';
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
  QueryEvent? _activeQuery;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQuerySelected(QueryEvent query) {
    widget.onQueryTap(query);
    if (_activeQuery?.eventId != query.eventId) {
      setState(() => _activeQuery = query);
    }
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

    if (queries.isEmpty) {
      return const EmptyState(message: 'No queries yet');
    }

    final filtered = _filtered(queries);

    return Column(
      children: [
        QuerySearchBar(
          controller: _controller,
          onChanged: (s) => setState(() => _search = s.toLowerCase()),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: EmptyState(message: 'No queries match "$_search".'),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final query = filtered[i];
              return QueryRow(
                query: query,
                onTap: () => _onQuerySelected(query),
                isActive: _activeQuery?.eventId == query.eventId,
              );
            },
          ),
        ),
      ],
    );
  }
}
