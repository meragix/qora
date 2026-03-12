import 'package:flutter/material.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/ui/state/timeline_controller.dart';
import 'package:qora_devtools_ui/src/ui/widgets/json_tree_viewer.dart';

/// Data Diff tab — shows a before/after comparison for the most recent
/// settled mutation visible in the timeline.
///
/// "Before" = variables sent to the mutator (what the app submitted).
/// "After"  = result returned (server response on success, error on failure).
class DataDiffTab extends StatelessWidget {
  /// Creates the data diff tab.
  const DataDiffTab({super.key, required this.controller});

  /// Timeline controller used to find the most recent settled mutation.
  final TimelineController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settled = controller.events
            .whereType<MutationEvent>()
            .where((e) => e.type == MutationEventType.settled)
            .firstOrNull;

        if (settled == null) {
          return const Center(
            child: Text(
              'No settled mutations yet.\nPerform a mutation to see the diff.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return _DiffView(event: settled);
      },
    );
  }
}

// ── Diff view ─────────────────────────────────────────────────────────────────

class _DiffView extends StatelessWidget {
  const _DiffView({required this.event});

  final MutationEvent event;

  @override
  Widget build(BuildContext context) {
    final isSuccess = event.success ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _DiffColumn(
            label: 'BEFORE',
            labelColor: const Color(0xFF475569),
            value: event.variables,
            emptyText: 'No variables',
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _DiffColumn(
            label: isSuccess ? 'AFTER (success)' : 'AFTER (error)',
            labelColor:
                isSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
            value: event.result,
            emptyText: isSuccess ? 'No result data' : 'No error details',
          ),
        ),
      ],
    );
  }
}

// ── Diff column ───────────────────────────────────────────────────────────────

class _DiffColumn extends StatelessWidget {
  const _DiffColumn({
    required this.label,
    required this.labelColor,
    required this.value,
    required this.emptyText,
  });

  final String label;
  final Color labelColor;
  final Object? value;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: labelColor.withValues(alpha: 0.08),
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: value != null
                ? JsonTreeViewer(value: value)
                : Text(
                    emptyText,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
          ),
        ),
      ],
    );
  }
}
