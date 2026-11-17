import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_queue_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/panel/inspector/inspector_widgets.dart';
import 'package:qora_devtools_overlay/src/ui/panel/list/queue/queue_status_color.dart';
import 'package:qora_devtools_overlay/src/ui/shared/empty_state.dart';
import 'package:qora_devtools_overlay/src/ui/shared/json_viewer.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

/// Details of the selected call of the mutation queue.
class QueueInspector extends StatelessWidget {
  const QueueInspector({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MutationQueueNotifier>();
    final entry = notifier.selected;

    if (entry == null) {
      return EmptyState(
        message: notifier.selectedId == null
            ? 'Select a queued call to inspect'
            : 'This call left the queue: it was sent, the app discarded '
                'it, or the app retried it with new variables, which gives '
                'it a new mutation id.',
      );
    }

    final error = entry.lastError;
    return ListView(
      padding: 12.edgeInsetsA,
      children: [
        InspectorSection(
          label: 'MUTATION KEY',
          child: Text(entry.key, style: DevtoolsTypography.code),
        ),
        InspectorSection(
          label: 'STATUS',
          child: Text(
            entry.status.name.toUpperCase(),
            style: DevtoolsTypography.code.copyWith(
              color: queueStatusColor(entry.status),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        InspectorSection(
          label: 'METADATA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InspectorMetaRow('Mutation Id:', entry.mutationId),
              InspectorMetaRow('Scope:', entry.scope ?? 'none (global lane)'),
              InspectorMetaRow('Enqueued At:', entry.enqueuedAt.fmtDateTime()),
              InspectorMetaRow('Attempts:', '${entry.attempts}'),
            ],
          ),
        ),
        if (error != null)
          InspectorSection(
            label: 'LAST ERROR',
            child: SelectableText(
              '$error',
              style: DevtoolsTypography.code
                  .copyWith(color: DevtoolsColors.red400),
            ),
          ),
        InspectorSection(
          label: 'VARIABLES',
          showDivider: false,
          child: JsonViewer(
            key: ValueKey('${entry.mutationId}_vars'),
            data: _displayable(entry.variables),
          ),
        ),
      ],
    );
  }
}

/// Variables are the objects passed to `mutate`. A JSON round trip calls
/// `toJson()` at every level (nested models, lists of models), so the JSON
/// viewer can expand them; without a `toJson()` they show as `toString()`.
Object? _displayable(Object? variables) {
  try {
    return jsonDecode(jsonEncode(variables));
  } catch (_) {
    return variables;
  }
}
