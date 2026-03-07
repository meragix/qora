import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/shared/breadcrumb_key.dart';
import 'package:qora_devtools_overlay/src/ui/shared/status_badge.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class MutationRow extends StatelessWidget {
  final MutationEvent mutation;
  final VoidCallback onTap;

  const MutationRow({super.key, required this.mutation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BreadcrumbKey(queryKey: mutation.key),
                  const SizedBox(height: 2),
                  Text(
                    mutation.id,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: _statusFrom(mutation)),
          ],
        ),
      ),
    );
  }

  String _statusFrom(MutationEvent e) {
    if (e.type == MutationEventType.settled) {
      return (e.success ?? false) ? 'success' : 'error';
    }
    return 'pending';
  }
}
