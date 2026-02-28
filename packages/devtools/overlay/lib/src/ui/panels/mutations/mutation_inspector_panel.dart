import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panels/shared/expandable_object.dart';
import 'package:qora_devtools_overlay/src/ui/panels/shared/status_badge.dart';

/// Inspector column (column 2) for the Mutations panel.
///
/// Displays STATUS / ACTIONS / VARIABLES / ERROR / ROLLBACK CONTEXT / METADATA
/// sections for the mutation selected in [MutationListColumn].
class MutationInspectorColumn extends StatelessWidget {
  const MutationInspectorColumn({super.key});

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<MutationInspectorNotifier>().detail;

    if (detail == null) {
      return const Center(
        child: Text(
          'Select a mutation',
          style: TextStyle(color: Color(0xFF475569), fontSize: 13),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // STATUS
        _Section(
          label: 'STATUS',
          child: StatusBadge(status: detail.status),
        ),

        // ACTIONS
        _Section(
          label: 'ACTIONS',
          child: Row(children: [
            if (detail.status == 'error')
              _RetryButton(
                onTap: () => context.read<MutationInspectorNotifier>().retry(),
              ),
          ]),
        ),

        // VARIABLES
        _Section(
          label: 'VARIABLES',
          child: ExpandableObject(
            label: 'Object(${detail.variablesCount})',
            preview: detail.variablesPreview,
          ),
        ),

        // ERROR — conditional
        if (detail.errorPreview != null)
          _Section(
            label: 'ERROR',
            child: ExpandableObject(
              label: 'Object(${detail.errorCount})',
              preview: detail.errorPreview,
              isError: true,
            ),
          ),

        // ROLLBACK CONTEXT — optimistic updates only
        if (detail.rollbackContextPreview != null)
          _Section(
            label: 'ROLLBACK CONTEXT',
            child: ExpandableObject(
              label: 'Object(${detail.rollbackCount})',
              preview: detail.rollbackContextPreview,
            ),
          ),

        // METADATA
        _Section(
          label: 'METADATA',
          child: Column(children: [
            _MetaRow('Created At', _fmt(detail.createdAt)),
            if (detail.submittedAt != null)
              _MetaRow('Submitted At', _fmt(detail.submittedAt!)),
            if (detail.updatedAt != null)
              _MetaRow('Updated At', _fmt(detail.updatedAt!)),
            _MetaRow('Retry Count', '${detail.retryCount}'),
          ]),
        ),
      ],
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}.'
      '${dt.millisecond.toString().padLeft(3, '0')}';
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final Widget child;

  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RetryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 12, color: Color(0xFFE2E8F0)),
            SizedBox(width: 4),
            Text(
              'Retry',
              style: TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
