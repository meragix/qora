import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/queries_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panels/queries/query_row.dart';

/// Queries panel — displays all observed query keys with their latest status.
///
/// Reads [QueriesNotifier] from the widget tree (provided by [QoraInspector])
/// and renders one [QueryRow] per distinct query key.
class QueriesPanelView extends StatelessWidget {
  const QueriesPanelView({super.key});

  @override
  Widget build(BuildContext context) {
    final queries = context.watch<QueriesNotifier>().queries;

    if (queries.isEmpty) {
      return const Center(
        child: Text(
          'No queries yet',
          style: TextStyle(color: Color(0xFF475569), fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: queries.length,
      itemBuilder: (context, i) => QueryRow(query: queries[i]),
    );
  }
}
