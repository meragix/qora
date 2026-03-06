import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/queries_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panels/queries/queries_list.dart';
import 'package:qora_devtools_overlay/src/ui/panels/queries/query_row.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Queries panel — displays all observed query keys with their latest status.
///
/// Reads [QueriesNotifier] from the widget tree (provided by [QoraInspector])
/// and renders one [QueryRow] per distinct query key.
class QueriesPanelView extends StatefulWidget {
  const QueriesPanelView({super.key});

  @override
  State<QueriesPanelView> createState() => _QueriesPanelViewState();
}

class _QueriesPanelViewState extends State<QueriesPanelView> {
  QueryEvent? _activeQuery;

  void _onQuerySelected(QueryEvent query) {
    if (_activeQuery == query) return;
    setState(() => _activeQuery = query);
  }

  @override
  Widget build(BuildContext context) {
    final queries = context.watch<QueriesNotifier>().queries;

    if (queries.isEmpty) {
      return const _EmptyState();
    }

    return QueriesList(
      queries: queries,
      onSelectQuery: _onQuerySelected,
      selectedQueryId: _activeQuery?.eventId,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No queries yet',
        style: DevtoolsTypography.bodyMuted,
      ),
    );
  }
}
