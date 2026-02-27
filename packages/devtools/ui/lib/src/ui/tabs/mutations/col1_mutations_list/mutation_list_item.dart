import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/shared/breadcrumb_key.dart';
import 'package:qora_devtools_ui/src/ui/shared/status_dot.dart';

/// Single row for a mutation entry in the left mutations list.
class MutationListItem extends StatelessWidget {
  /// Creates a mutation list row.
  const MutationListItem({
    super.key,
    required this.title,
  });

  /// Row title or key breadcrumb.
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: const StatusDot(),
      title: BreadcrumbKey(value: title),
      subtitle: const Text('Waiting for events...'),
    );
  }
}
