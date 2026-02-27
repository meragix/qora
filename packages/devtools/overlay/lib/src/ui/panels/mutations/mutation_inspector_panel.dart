import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';

class MutationInspectorColumn extends StatelessWidget {
  const MutationInspectorColumn();

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<MutationInspectorNotifier>().detail;

    if (detail == null) {
      return const Center(
        child: Text('Select a mutation', style: TextStyle(color: Color(0xFF475569), fontSize: 13)),
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
            if (detail.status == QueryStatus.error)
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

        // ERROR — conditionnel
        if (detail.errorPreview != null)
          _Section(
            label: 'ERROR',
            child: ExpandableObject(
              label: 'Object(${detail.errorCount})',
              preview: detail.errorPreview,
              isError: true,
            ),
          ),

        // ROLLBACK CONTEXT — si optimistic update
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
            if (detail.submittedAt != null) _MetaRow('Submitted At', _fmt(detail.submittedAt!)),
            if (detail.updatedAt != null) _MetaRow('Updated At', _fmt(detail.updatedAt!)),
            _MetaRow('Retry Count', '${detail.retryCount}'),
          ]),
        ),
      ],
    );
  }

  String _fmt(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}.'
      '${dt.millisecond.toString().padLeft(3, '0')} AM';
}
