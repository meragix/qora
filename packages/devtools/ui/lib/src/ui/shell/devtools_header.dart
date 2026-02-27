import 'package:flutter/material.dart';

/// Header displayed at the top of the DevTools extension shell.
class DevtoolsHeader extends StatelessWidget {
  /// Creates a header widget.
  const DevtoolsHeader({
    super.key,
    required this.activeQueryCount,
  });

  /// Number of currently active queries.
  final int activeQueryCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Text(
          'Qora Devtools',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('$activeQueryCount queries active'),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Expand',
          onPressed: () {},
          icon: const Icon(Icons.open_in_full, size: 18),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () {},
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    );
  }
}
