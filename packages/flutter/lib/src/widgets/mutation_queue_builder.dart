import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:qora/qora.dart';

import 'qora_scope.dart';

/// A widget that rebuilds whenever the calls in a [MutationQueue] change: a
/// call queued, sent, retried, failed, discarded or done.
///
/// The queue holds the registered mutations called with
/// `MutationOptions(offlineQueue: true)`, online or not, and, with
/// `PersistQoraClient`, the calls restored by `hydrate()` after a restart.
/// [builder] receives [MutationQueue.entries], in order:
///
/// ```dart
/// MutationQueueBuilder(
///   builder: (context, entries, child) {
///     final needsAction = entries.where(
///       (e) =>
///           e.status == QueuedMutationStatus.blocked ||
///           e.status == QueuedMutationStatus.failed,
///     );
///     if (needsAction.isNotEmpty) {
///       return Text('${needsAction.length} change(s) need your attention');
///     }
///     if (entries.isNotEmpty) return Text('${entries.length} change(s) to sync');
///     return const SizedBox.shrink();
///   },
/// )
/// ```
///
/// Decide on a `blocked` or `failed` call with [MutationQueue.retry] or
/// [MutationQueue.discard], through `context.qora.mutationQueue`.
///
/// Reads the queue of [client], or of the nearest [QoraScope] when [client]
/// is null, and follows it if that client changes.
class MutationQueueBuilder extends StatefulWidget {
  /// Builds the widget tree for the current calls.
  ///
  /// Called with [MutationQueue.entries] at first build, then each time they
  /// change. Changes made in one synchronous run cause one call.
  final Widget Function(
    BuildContext context,
    List<QueuedMutation> entries,
    Widget? child,
  ) builder;

  /// Optional child widget passed through to [builder] unchanged.
  ///
  /// Use this to avoid rebuilding expensive subtrees when the queue changes.
  final Widget? child;

  /// The client whose queue to read. Defaults to the nearest [QoraScope].
  final QoraClient? client;

  const MutationQueueBuilder({
    super.key,
    required this.builder,
    this.child,
    this.client,
  });

  @override
  State<MutationQueueBuilder> createState() => _MutationQueueBuilderState();
}

class _MutationQueueBuilderState extends State<MutationQueueBuilder> {
  MutationQueue? _queue;
  StreamSubscription<List<QueuedMutation>>? _subscription;
  List<QueuedMutation> _entries = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _follow();
  }

  @override
  void didUpdateWidget(MutationQueueBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.client, oldWidget.client)) _follow();
  }

  void _follow() {
    final queue = (widget.client ?? QoraScope.of(context)).mutationQueue;
    if (identical(queue, _queue)) return;
    _subscription?.cancel();
    _queue = queue;
    // Read, then listen, in the same synchronous run: a change made after
    // the read is reported to the new listener.
    _entries = queue.entries;
    _subscription = queue.entriesStream.listen((entries) {
      if (mounted) setState(() => _entries = entries);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _entries, widget.child);
}
