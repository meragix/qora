import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/panels/shared/breadcrumb_key.dart';
import 'package:qora_devtools_overlay/src/ui/panels/shared/status_badge.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Single row in the Queries panel list.
///
/// Displays the [QueryEvent.key] as a [BreadcrumbKey] breadcrumb on the left
/// and the current status badge on the right.
class QueryRow extends StatelessWidget {
  final QueryEvent query;

  const QueryRow({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Expanded(child: BreadcrumbKey(queryKey: query.key)),
          const SizedBox(width: 8),
          StatusBadge(status: query.status ?? 'unknown'),
        ],
      ),
    );
  }
}
