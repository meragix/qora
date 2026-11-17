import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/mutation/mutation_inspector.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/query/query_inspector.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/queue/queue_inspector.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

/// What the inspector column shows: the selection of the list tab last used.
enum InspectorKind { query, mutation, queue }

/// Dispatches to [QueryInspector], [MutationInspector] or [QueueInspector]
/// based on [kind], under a header naming it.
class InspectorPanel extends StatelessWidget {
  final InspectorKind kind;

  const InspectorPanel({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        _InspectorHeader(kind: kind),

        // ── Content ────────────────────────────────────────────────────────
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: switch (kind) {
              InspectorKind.query =>
                const QueryInspector(key: ValueKey('query')),
              InspectorKind.mutation =>
                const MutationInspector(key: ValueKey('mutation')),
              InspectorKind.queue =>
                const QueueInspector(key: ValueKey('queue')),
            },
          ),
        ),
      ],
    );
  }
}

class _InspectorHeader extends StatelessWidget {
  final InspectorKind kind;
  const _InspectorHeader({required this.kind});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DevtoolsColors.border)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        switch (kind) {
          InspectorKind.query => 'INSPECTOR',
          InspectorKind.mutation => 'MUTATION INSPECTOR',
          InspectorKind.queue => 'QUEUE INSPECTOR',
        },
        key: ValueKey(kind),
        style: DevtoolsTypography.tab.copyWith(letterSpacing: 0.6),
      ),
    );
  }
}
