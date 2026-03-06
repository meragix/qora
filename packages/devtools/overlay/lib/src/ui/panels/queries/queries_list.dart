import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:qora_devtools_overlay/src/ui/panels/queries/query_row.dart';
import 'package:qora_devtools_overlay/src/ui/panels/queries/query_search_bar.dart';
import 'package:qora_devtools_overlay/utils/query_utils.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class QueriesList extends StatefulWidget {
  final List<QueryEvent> queries;
  final ValueChanged<QueryEvent> onSelectQuery;
  final String? selectedQueryId;

  const QueriesList({
    super.key,
    required this.queries,
    required this.onSelectQuery,
    required this.selectedQueryId,
  });

  @override
  State<QueriesList> createState() => _QueriesListState();
}

class _QueriesListState extends State<QueriesList> {
  final _controller = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final value = _controller.text.toLowerCase();
    if (value == _search) return;
    setState(() => _search = value);
  }

  List<QueryEvent> get _filteredQueries {
    if (_search.isEmpty) return widget.queries;
    return widget.queries.where((q) => formatQueryKey(q.key).toLowerCase().contains(_search)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQueries;

    return Column(
      children: [
        QuerySearchBar(
          controller: _controller,
          onChanged: (s) => setState(() => _search = s.toLowerCase()),
        ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No queries found.',
              style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final query = filtered[i];

              return QueryRow(
                query: query,
                onTap: () => widget.onSelectQuery(query),
                isActive: widget.selectedQueryId == query.eventId,
              );
            },
          ),
        ),
      ],
    );
  }
}
